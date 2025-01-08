// MB50DEV assembler

#include "mb50common.hpp"

#include <__expected/unexpected.h>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <ios>
#include <iostream>
#include <limits>
#include <map>
#include <ostream>
#include <stack>
#include <string>
#include <tuple>
#include <utility>
#include <variant>

namespace sfs = std::filesystem;

/*** Declarations ************************************************************/

// Position in source
class src_pos {
public:
    src_pos(const std::string& path, size_t line): path(path), line(line) {}
    const std::string& path;
    const size_t line;
};

// All input files
class input {
public:
    using text_t = std::vector<std::string>; // lines of a file
    using text_span = std::span<const std::string>; // read-only refence to an interval of lines
    struct file_t;
    using files_t = std::map<sfs::path, file_t>; // keys are absolute paths
    using name_spaces_t = std::map<std::string, files_t::const_iterator>;
    struct file_t {
        sfs::path orig_path; // from $use directive
        text_t full_text; // original, with comments, without trailing whitespace
        text_t text; // without comments and trailing whitespace
        name_spaces_t name_spaces; // of files included by $use
        bool processed;
    };
    input(sfs::path file, bool verbose);
    [[nodiscard]] std::pair<const files_t&, files_t::const_iterator> files() const {
        return {_files, _top_file};
    }
private:
    // Adds a file by $use on line in already read file from (files.end() if adding a top level file)
    files_t::iterator add_file(files_t::iterator from, size_t line, sfs::path relative, const std::string& name_space);
    // Read a file unless already processed
    std::vector<files_t::iterator> read(files_t::iterator it);
    files_t _files;
    files_t::const_iterator _top_file;
    bool verbose;
};

// Output files
class output {
public:
    // Construct output file names from input file name
    output(sfs::path file, bool verbose);
    // Stores binary data for all output files, and an optional instruction for the text output file
    void add_bytes(uint16_t addr, std::span<uint8_t> bytes, std::string_view instr, std::string_view prefix);
    // Stores a source line for text output file
    void add_src_line(const sfs::path& file, size_t line, std::string_view text, std::string_view prefix,
                      std::string_view macro_prefix);
    void add_txt_line(std::string_view text, std::string_view prefix);
    void set_byte(uint16_t addr, uint8_t byte);
    void set_word(uint16_t addr, uint16_t word);
    // Writes all output files
    void write();
    size_t last_line = 0;
private:
    struct out_line_t {
        std::string text{};
        std::span<uint8_t> bytes{};
    };
    sfs::path file{}; // the input file name
    sfs::path last_file{};
    std::vector<out_line_t> out_text{};
    std::array<uint8_t, 0x10000> out_bin{}; // The full address space
    size_t start_addr = 0x10000; // Write part of the address space starting from this address
    size_t end_addr = 0x0000; // One after the last byte written
    bool verbose = false;
};

// Assembler
class assembler {
public:
    struct line_t {
        std::string_view label;
        std::string_view cmd;
        std::vector<std::string_view> args;
    };
    assembler(input& in, output& out, bool verbose);
    void run();
    static std::string remove_comment(std::string_view line);
    // Expects a line without comment
    static line_t split(std::string_view line);
private:
    class expr_base;
    class expr_number;
    class expr_const;
    class expr_label;
    class expr_bytes;
    class expr_reg;
    class expr_addr;
    class expr_binop;
    class expr_unop;
    class expr_or;
    class expr_xor;
    class expr_and;
    class expr_shl;
    class expr_shr;
    class expr_add;
    class expr_sub;
    class expr_mul;
    class expr_div;
    class expr_rem;
    class expr_not;
    class expr_neg;
    // second phase of expression evaluation
    struct phase2_t {
        std::shared_ptr<expr_base> expr; // evaluate this expression
        uint16_t addr; // store value here
        bool word; // false = byte, true = word
    };
    // label definition
    class label_t {
    public:
        explicit label_t(std::optional<uint16_t> v = std::nullopt): _value(v), _fixed(!v) {}
        label_t(std::optional<uint16_t> v, bool fixed): _value(v), _fixed(fixed) {}
        std::optional<uint16_t> value() const {
            return _value;
        }
        bool set(uint16_t v) const {
            if (_value)
                return false;
            else {
                _value = v;
                return true;
            }
        }
        bool fixed() const {
            return _fixed;
        }
        void fix() const {
            _fixed = true;
        }
    private:
        mutable std::optional<uint16_t> _value;
        mutable bool _fixed = false;
    };
    // expression that must be always evaluated
    struct var_t {
        std::shared_ptr<expr_base> expr;
    };
    // macro definition
    struct macro_t {
        std::vector<std::string> params; // names of parameters of this macro
        input::files_t::const_iterator file; // file containing the macro definition
        input::text_span full_replace; // replacement text: original, with comments, without trailing whitespace
        input::text_span replace; // replacement text: without comments and trailing whitespace
        size_t order; // ordering of macro definitions
    };
    using symbol_t = std::variant<label_t, var_t, macro_t>;
    using symbol_table_t = std::map<std::string, std::shared_ptr<symbol_t>>;
    using global_symbol_table_t = std::map<std::string, std::shared_ptr<symbol_t>>;
    using macro_args_t = std::map<std::string, std::shared_ptr<expr_base>>;
    using parse_expr_t = std::expected<std::shared_ptr<expr_base>, std::string>;
    using parse_fun_t =
        std::pair<assembler::parse_expr_t, std::string_view> (assembler::*)(std::string_view,
                                                                            input::files_t::const_iterator,
                                                                            macro_args_t*,
                                                                            parser::id_macro_t);
    struct instruction_t {
        uint8_t opcode = 0x00; // the first (lower) byte of the instruction
        bool dst_csr = false; // destination is CSR
        bool src_csr = false; // source is CSR
    };
    void run_file(const input::files_t& files, input::files_t::const_iterator current);
    // macro_args != nullptr when expanding a macro; cur_macro is for label$
    void run_lines(const input::files_t& files, input::files_t::const_iterator current,
                   input::text_span full_text, input::text_span text,
                   size_t macro_idx = std::numeric_limits<decltype(macro_idx)>::max(),
                   macro_args_t* macro_args = nullptr, size_t macro_level = 0);
    // false if symbol name already defined, true otherwise
    bool define_const(input::files_t::const_iterator file, std::string name,
                      std::shared_ptr<assembler::expr_base> expr);
    // false if symbol name already defined, true otherwise
    bool define_label(input::files_t::const_iterator file, std::string name, std::optional<uint16_t> addr, bool global);
    // false if symbol name already defined, true otherwise
    bool define_macro(input::files_t::const_iterator file, std::string name, input::text_span full_replace,
                      input::text_span replace, std::vector<std::string> params);
    void define_global(std::string name, std::shared_ptr<symbol_t> sym, bool multi);
    // bool = whether the symbol is defined; {nullptr, true} = unqualified name with multiple definitions
    std::pair<const symbol_t*, bool> find_symbol(input::files_t::const_iterator file, const parser::ident_t& id,
                                                 bool def_as_label = false);
    parse_expr_t parse_expr(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                            parser::id_macro_t macro_id);
    template<parse_fun_t F, std::derived_from<expr_base> ...E>
        std::pair<assembler::parse_expr_t, std::string_view>
        parse_expr_binary(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                          parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr_term(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                        parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr_unary(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                         parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr0_or(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                       parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr1_xor(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                        parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr2_and(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                        parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr3_shift(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                          parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr4_additive(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                             parser::id_macro_t macro_id);
    std::pair<parse_expr_t, std::string_view>
        parse_expr5_multiplicative(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                                   parser::id_macro_t macro_id);
    input& in;
    output& out;
    bool verbose;
    std::map<input::files_t::const_iterator, symbol_table_t, decltype([](auto&& a, auto&& b){ return &*a < &*b; })>
        symbols;
    global_symbol_table_t global_symbols;
    symbol_table_t predef_symbols;
    size_t macro_def_order = 0;
    size_t max_macro = 0; // for label$
    uint16_t cur_addr = 0; // current output address
    std::vector<phase2_t> phase2;
    std::map<std::string, instruction_t> opcodes;
};

// expression base
class assembler::expr_base {
public:
    expr_base() = default;
    expr_base(const expr_base&) = delete;
    expr_base(expr_base&&) = delete;
    expr_base& operator=(const expr_base&) = delete;
    expr_base& operator=(expr_base&&) = delete;
    virtual ~expr_base() = default;
    virtual std::optional<uint16_t> eval() {
        return std::nullopt;
    }
    // this function provides special handling of symbol __addr
    virtual std::shared_ptr<expr_base> fixed_clone(std::shared_ptr<expr_base> obj) {
        return obj;
    }
    // returns a sequence of bytes; after nullopt in the first phase, length 1 is expected for the second phase
    virtual std::optional<std::vector<uint8_t>> eval_bytes() {
        if (auto val = eval())
            return {{uint8_t(*val % 256U)}};
        else
            return std::nullopt;
    }
    // returns a register index 0..15 and false = normal register, true = CSR
    virtual std::optional<std::pair<uint8_t, bool>> eval_reg() {
        return std::nullopt;
    }
    [[nodiscard]] virtual std::string eval_reg_str() const {
        return "?";
    }
};

// expression returing a number
class assembler::expr_number: public assembler::expr_base {
};

// expression returning a constant number
class assembler::expr_const: public assembler::expr_number {
public:
    explicit expr_const(uint16_t value): value(value) {}
    std::optional<uint16_t> eval() override {
        return value;
    }
private:
    uint16_t value;
};

// expression returning a label
class assembler::expr_label: public assembler::expr_number {
public:
    explicit expr_label(const label_t& label): label(label) {}
    std::optional<uint16_t> eval() override {
        return label.value();
    }
private:
    const label_t& label;
};

// expression returning a constant sequence of bytes
class assembler::expr_bytes: public assembler::expr_base {
public:
    explicit expr_bytes(std::vector<uint8_t> bytes): bytes(std::move(bytes)) {}
    std::optional<std::vector<uint8_t>> eval_bytes() override {
        return bytes;
    }
private:
    std::vector<uint8_t> bytes;
};

// register selector for an instruction
class assembler::expr_reg: public assembler::expr_base {
public:
    expr_reg(uint8_t idx, bool csr): idx(idx), csr(csr) {}
    std::optional<std::pair<uint8_t, bool>> eval_reg() override {
        return {{decltype(idx){idx}, decltype(csr){csr}}};
    }
    [[nodiscard]] std::string eval_reg_str() const override {
        return std::format("{}r{}", csr ? "cs" : "", uint8_t(idx));
    }
private:
    uint8_t idx: 4;
    bool csr: 1;
};

// the current address
class assembler::expr_addr: public assembler::expr_number {
public:
    explicit expr_addr(assembler& as): addr(as.cur_addr) {}
    std::optional<uint16_t> eval() override {
        return addr;
    }
    std::shared_ptr<expr_base> fixed_clone(std::shared_ptr<expr_base>) override {
        return std::make_shared<expr_const>(addr);
    }
private:
    const uint16_t& addr;
};

// a binary operation
class assembler::expr_binop: public assembler::expr_number {
public:
    expr_binop(std::shared_ptr<expr_base> left, std::shared_ptr<expr_base> right):
        left(std::move(left)), right(std::move(right)) {}
protected:
    std::shared_ptr<expr_base> left;
    std::shared_ptr<expr_base> right;
};

// an unary operation
class assembler::expr_unop: public assembler::expr_number {
public:
    explicit expr_unop(std::shared_ptr<expr_base> inner): inner(std::move(inner)) {}
protected:
    std::shared_ptr<expr_base> inner;
};

class assembler::expr_or: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "|";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l | *r);
        return std::nullopt;
    }
};

class assembler::expr_xor: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "^";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l ^ *r);
        return std::nullopt;
    }
};

class assembler::expr_and: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "&";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l & *r);
        return std::nullopt;
    }
};

class assembler::expr_shl: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "<<";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l << std::max(uint16_t(0), std::min(*r, uint16_t(16))));
        return std::nullopt;
    }
};

class assembler::expr_shr: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = ">>";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l >> std::max(uint16_t(0), std::min(*r, uint16_t(16))));
        return std::nullopt;
    }
};

class assembler::expr_add: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "+";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l + *r);
        return std::nullopt;
    }
};

class assembler::expr_sub: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "-";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l - *r);
        return std::nullopt;
    }
};

class assembler::expr_mul: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "*";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r)
            return uint16_t(*l * *r);
        return std::nullopt;
    }
};

class assembler::expr_div: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "/";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r && *r != 0)
            return uint16_t(*l / *r);
        return std::nullopt;
    }
};

class assembler::expr_rem: public assembler::expr_binop {
    using expr_binop::expr_binop;
public:
    static constexpr std::string_view op = "%";
    std::optional<uint16_t> eval() override {
        if (auto [l, r] = std::pair{left->eval(), right->eval()}; l && r && *r != 0)
            return uint16_t(*l % *r);
        return std::nullopt;
    }
};

class assembler::expr_not: public assembler::expr_unop {
    using expr_unop::expr_unop;
public:
    std::optional<uint16_t> eval() override {
        if (auto i = inner->eval(); i)
            return uint16_t(~*i);
        return std::nullopt;
    }
};

class assembler::expr_neg: public assembler::expr_unop {
    using expr_unop::expr_unop;
public:
    std::optional<uint16_t> eval() override {
        if (auto i = inner->eval(); i)
            return uint16_t(-*i);
        return std::nullopt;
    }
};

/*** src_pos *****************************************************************/

std::ostream& operator<<(std::ostream& os, const src_pos& pos)
{
    os << pos.path << ':' << pos.line << ": ";
    return os;
}

/*** input *******************************************************************/

input::input(sfs::path file, bool verbose):
    verbose(verbose)
{
    std::stack<files_t::iterator> todo{};
    todo.push(add_file(_files.end(), 0, std::move(file), ""s));
    while (!todo.empty()) {
        files_t::iterator p = todo.top();
        todo.pop();
        todo.push_range(read(p) | std::ranges::views::reverse);
    }
}

input::files_t::iterator
input::add_file(files_t::iterator from, size_t line, sfs::path relative, const std::string& name_space)
{
    sfs::path abs = relative;
    if (abs.is_relative()) {
        sfs::path base = from != _files.end() ? from->first : sfs::path{};
        base.remove_filename();
        abs = base / abs;
    }
    abs = sfs::canonical(abs);
    auto [result, added] = _files.insert({
        std::move(abs),
        file_t{
            .orig_path = std::move(relative),
            .full_text = {},
            .text = {},
            .name_spaces = {},
            .processed = false,
        }});
    if (from == _files.end())
        _top_file = result;
    else {
        if (from->second.name_spaces.contains(name_space)) {
            std::cerr << src_pos(from->first, line) << "Namespace " << name_space << " already defined" <<
                std::endl;
            throw silent_error{};
        } else {
            if (verbose) {
                std::cerr << src_pos(from->first, line) << "Namespace " << name_space << " -> \"" << result->first <<
                    '"';
                if (!added)
                    std::cerr << " already read";
                std::cerr << std::endl;
            }
            from->second.name_spaces[name_space] = result;
        }
    }
    return result;
}

std::vector<input::files_t::iterator> input::read(files_t::iterator it)
{
    std::vector<input::files_t::iterator> result{};
    if (it->second.processed)
        return result;
    if (verbose)
        std::cerr << "Reading file \"" << it->first.string() << '"' << std::endl;
    it->second.processed = true;
    if (std::ifstream ifs{it->first}; !ifs) {
        std::cerr << "Cannot read file \"" << it->first.string() << '"' << std::endl;
        throw silent_error{};
    } else {
        file_t& f = it->second;
        for (std::string line; std::getline(ifs, line);) {
            if (auto e = line.find_last_not_of(whitespace_chars); e == std::string::npos)
                line.clear();
            else
                line.resize(e + 1);
            f.full_text.push_back(line);
            f.text.push_back(assembler::remove_comment(line));
            auto parts = assembler::split(f.text.back());
            if (parts.cmd == "$use"sv) {
                if (parts.args.size() != 2 || parts.args[1].empty()) {
                    std::cerr << src_pos(it->first, f.text.size()) << "Expected namespace, file_name" << std::endl;
                    throw silent_error{};
                }
                auto id_ns = parser::identifier(parts.args[0], true);
                if (!id_ns.first) {
                    std::cerr << src_pos(it->first, f.text.size()) << "Expected namespace: " << id_ns.first.error() <<
                        std::endl;
                    throw silent_error{};
                }
                if (id_ns.first->name_space) {
                    std::cerr << src_pos(it->first, f.text.size()) << "Expected identifier without namespace" <<
                        std::endl;
                    throw silent_error{};
                }
                result.push_back(add_file(it, f.text.size(), parts.args[1], id_ns.first->name));
            }
        }
    }
    return result;
}

/*** output ******************************************************************/

output::output(sfs::path file, bool verbose):
    file(std::move(file)), verbose(verbose)
{
    this->file.replace_extension();
}

void output::add_bytes(uint16_t addr, std::span<uint8_t> bytes, std::string_view instr, std::string_view prefix)
{
    if (addr + bytes.size() > out_bin.size())
        throw fatal_error("Output does not fit to address space");
    if (addr < start_addr)
        start_addr = addr;
    if (addr + bytes.size() > end_addr)
        end_addr = addr + bytes.size();
    auto addr_begin = out_bin.begin() + addr;
    auto addr_end = std::ranges::copy(bytes, addr_begin).out;
    if (!instr.empty())
        out_text.push_back({.text = std::format("; {}{:04x}: {}", prefix, addr, instr)});
    out_text.push_back({.text = std::format("; {}{:04x}: $data_b", prefix, addr), .bytes = {addr_begin, addr_end}});
}

void output::add_src_line(const sfs::path& file, size_t line, std::string_view text, std::string_view prefix,
                          std::string_view macro_prefix)
{
    if (file != last_file || line != last_line + 1 || !macro_prefix.empty()) {
        out_text.push_back({.text = std::format("; {}{}{}:{}", prefix.size() >= 2 ? prefix.substr(2) : prefix,
                                                macro_prefix, file.string(), line)});
        last_file = file;
    }
    last_line = line;
    out_text.push_back({.text = std::string(prefix).append(text)});
}

void output::add_txt_line(std::string_view text, std::string_view prefix)
{
    out_text.push_back({.text = std::format("; {}{}", prefix, text)});
}

void output::set_byte(uint16_t addr, uint8_t byte)
{
    out_bin.at(addr) = byte;
}

void output::set_word(uint16_t addr, uint16_t word)
{
    out_bin.at(addr) = uint8_t(word % 256U);
    out_bin.at(addr + 1) = uint8_t(word / 256U);
}

void output::write()
{
    std::ofstream ofs;
    if (start_addr >= out_bin.size() || end_addr > out_bin.size() || end_addr <= start_addr) {
        start_addr = 0x0000;
        end_addr = 0x0000;
    }
    auto out_size = std::streamsize(end_addr - start_addr);

    sfs::path out_file = file;
    out_file.replace_extension(".bin");
    if (verbose)
        std::cerr << "Writing file \"" << out_file.string() << '"' << std::endl;
    ofs.open(out_file, std::ios_base::binary | std::ios_base::trunc);
    if (!ofs)
        throw fatal_error(std::format("Cannot write binary output file \"{}\"", out_file.string()));
    ofs << std::format("{:04x}\n", start_addr);
    if (out_size > 0)
        ofs.write(reinterpret_cast<const char*>(out_bin.data() + start_addr), out_size);
    ofs.close();
    if (!ofs)
        throw fatal_error(std::format("Error writing binary output file \"{}\"", out_file.string()));

    out_file = file;
    out_file.replace_extension(".mif");
    if (verbose)
        std::cerr << "Writing file \"" << out_file.string() << '"' << std::endl;
    ofs.open(out_file, std::ios_base::binary | std::ios_base::trunc);
    if (!ofs)
        throw fatal_error(std::format("Cannot write MIF output file \"{}\"", out_file.string()));
    ofs << R"(-- mb50as generated Memory Initialization File (.mif)

WIDTH=8;
DEPTH=30720;

ADDRESS_RADIX=HEX;
DATA_RADIX=HEX;

CONTENT BEGIN
)";
    for (size_t addr = start_addr; addr < end_addr; ++addr)
        ofs << std::format("\t{:04x}: {:02x};\n", addr, out_bin[addr]);
    ofs << "END;\n";
    ofs.close();
    if (!ofs)
        throw fatal_error(std::format("Error writing MIF output file \"{}\"", out_file.string()));

    out_file = file;
    out_file.replace_extension(".out");
    if (verbose)
        std::cerr << "Writing file \"" << out_file.string() << '"' << std::endl;
    ofs.open(out_file, std::ios_base::trunc);
    if (!ofs)
        throw fatal_error(std::format("Cannot write text output file \"{}\"", out_file.string()));
    for (auto&&l: out_text) {
        ofs << l.text;
        std::string delim = " "s;
        for (auto b: l.bytes) {
            ofs << delim << std::format("{:#04x}", b);
            delim = ", "s;
        }
        if (l.bytes.size() == 2)
            ofs << std::format(" # 0x{:02x}{:02x}", l.bytes[1], l.bytes[0]);
        ofs << '\n';
    }
    ofs.close();
    if (!ofs)
        throw fatal_error(std::format("Error writing text output file \"{}\"", out_file.string()));
}

/*** assembler ***************************************************************/

assembler::assembler(input& in, output& out, bool verbose):
    in(in), out(out), verbose(verbose),
    predef_symbols{
        {"sp", std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(11, false)})},
        {"ca", std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(12, false)})},
        {"ia", std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(13, false)})},
        {"f", std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(14, false)})},
        {"pc", std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(15, false)})},
        {"__addr", std::make_shared<symbol_t>(var_t{std::make_shared<expr_addr>(*this)})},
    },
    opcodes{
        {"add", {.opcode = 0x01}},
        {"and", {.opcode = 0x02}},
        {"cmps", {.opcode = 0x1b}},
        {"cmpu", {.opcode = 0x19}},
        {"csrr", {.opcode = 0x03, .src_csr = true}},
        {"csrw", {.opcode = 0x04, .dst_csr = true}},
        {"ddsto", {.opcode = 0x17}},
        {"dec1", {.opcode = 0x05}},
        {"dec2", {.opcode = 0x06}},
        {"exch", {.opcode = 0x07}},
        {"inc1", {.opcode = 0x08}},
        {"inc2", {.opcode = 0x09}},
        {"ill", {.opcode = 0x00}},
        {"ld", {.opcode = 0x0a}},
        {"ldb", {.opcode = 0x0b}},
        {"ldis", {.opcode = 0x0c}},
        //{"ldisx", {.opcode = 0x0d}},
        {"mulss", {.opcode = 0x1e}},
        {"mulsu", {.opcode = 0x1f}},
        {"mulus", {.opcode = 0x20}},
        {"muluu", {.opcode = 0x21}},
        {"mv", {.opcode = 0x0e}},
        {"neg", {.opcode = 0x0f}},
        {"not", {.opcode = 0x10}},
        {"or", {.opcode = 0x11}},
        {"reti", {.opcode = 0x1c}},
        {"rev", {.opcode = 0x1d}},
        {"shl", {.opcode = 0x12}},
        {"shr", {.opcode = 0x13}},
        {"shra", {.opcode = 0x14}},
        {"sto", {.opcode = 0x15}},
        {"stob", {.opcode = 0x16}},
        {"sub", {.opcode = 0x18}},
        {"xor", {.opcode = 0x1a}},
    }
{
    for (int i = 0; i <= 15; ++i) {
        predef_symbols.emplace(std::format("r{}", i),
                               std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(uint8_t(i), false)}));
        predef_symbols.emplace(std::format("csr{}", i),
                               std::make_shared<symbol_t>(var_t{std::make_shared<expr_reg>(uint8_t(i), true)}));
    }
    for (const auto& [prefix, suffix, opcode]: {
        //{"exch", "", 0x80},
         std::tuple{"ld", "", 0x90},
        {"ld", "is", 0xa0},
        //{"ldx", "is", 0xb0},
        {"mv", "", 0xc0},
    }) {
        for (const auto& [flag, f_code]: {
            std::tuple{"f0", 0x00},
            std::tuple{"f1", 0x01},
            std::tuple{"f2", 0x02},
            std::tuple{"f3", 0x03},
            std::tuple{"z", 0x04},
            std::tuple{"c", 0x05},
            std::tuple{"s", 0x06},
            std::tuple{"o", 0x07},
        }) {
            for (const auto& [neg, n_code]: {
                std::tuple{"", 0x08},
                std::tuple{"n", 0x00},
            }) {
                opcodes.emplace(std::format("{}{}{}{}", prefix, neg, flag, suffix),
                            instruction_t{.opcode = uint8_t(unsigned(opcode) | unsigned(n_code) | unsigned(f_code))});
            }
        }
    }
}

bool assembler::define_const(input::files_t::const_iterator file, std::string name,
                             std::shared_ptr<assembler::expr_base> expr)
{
    if (predef_symbols.contains(name))
        return false;
    if (auto it = symbols.find(file); it == symbols.end())
        throw fatal_error("Parsed file not in assembler::symbols ($const definition)");
    else
        if (auto [sym_it, added] = it->second.emplace(std::move(name),
                                                      std::make_shared<symbol_t>(var_t{.expr = std::move(expr)}));
            added)
        {
            define_global(sym_it->first, sym_it->second, false);
            return true;
        } else
            return false;
}

void assembler::define_global(std::string name, std::shared_ptr<symbol_t> symbol, bool multi)
{
    if (auto gl_it = global_symbols.find(name); gl_it != global_symbols.end()) {
        if (!multi)
            gl_it->second = nullptr; // multiple definitions
    } else
        global_symbols.emplace(std::move(name), std::move(symbol));
}

bool assembler::define_label(input::files_t::const_iterator file, std::string name, std::optional<uint16_t> addr,
                             bool global)
{
    if (predef_symbols.contains(name))
        return false;
    if (addr && global)
        throw fatal_error{"Cannot define global label with address"};
    if (!addr && global) {
        // caller ensures that name does not exist in global_symbols
        define_global(name, std::make_shared<symbol_t>(label_t{}), false);
        return true;
    }
    // local or qualified reference, or definition
    if (auto it = symbols.find(file); it == symbols.end())
        throw fatal_error("Parsed file not in assembler::symbols (label definition)");
    else {
        std::shared_ptr<symbol_t> symbol{};
        label_t* label = nullptr;
        auto gl_it = global_symbols.find(name);
        if (gl_it != global_symbols.end() && gl_it->second) {
            label = std::get_if<label_t>(gl_it->second.get());
            if (label) {
                // globally defined as label
                if (global)
                    symbol = gl_it->second;
                if (addr) {
                    if (label->value()) {
                        if (label->fixed())
                            return false; // already defined and referenced, cannot undefine
                        gl_it->second = nullptr; // multiple definitions of this label
                    } else
                        label->set(*addr);
                }
            } else
                gl_it->second = nullptr; // globally defined as not a label
        }
        if (!symbol)
            symbol = std::make_shared<symbol_t>(label_t{addr, false}); // not yet referenced as global label
        if (auto [sym_it, added] = it->second.emplace(std::move(name), symbol); added) {
            if (gl_it == global_symbols.end())
                define_global(sym_it->first, sym_it->second, !addr); // not defined, define with unknown or known value
            return true;
        } else
            if (auto label = std::get_if<label_t>(sym_it->second.get()); label && addr &&
                (!label->value() || label->value().value_or(0) == *addr)) // clang-tidy warns for *label->value()
            {
                // already defined with unknown value, set value
                label->set(*addr);
                return true;
            } else
                return false;
    }
}

bool assembler::define_macro(input::files_t::const_iterator file, std::string name, input::text_span full_replace,
                             input::text_span replace, std::vector<std::string> params)
{
    if (predef_symbols.contains(name) || opcodes.contains(name))
        return false;
    if (auto it = symbols.find(file); it == symbols.end())
        throw fatal_error("Parsed file not in assembler::symbols ($macro definition)");
    else
        if (auto [sym_it, added] = it->second.emplace(std::move(name),
                                                      std::make_shared<symbol_t>(macro_t{
                                                          .params = std::move(params),
                                                          .file = file,
                                                          .full_replace = full_replace,
                                                          .replace = replace,
                                                          .order = macro_def_order++,
                                                      }));
            added)
        {
            define_global(sym_it->first, sym_it->second, false);
            return true;
        } else
            return false;
}

std::pair<const assembler::symbol_t*, bool>
assembler::find_symbol(input::files_t::const_iterator file, const parser::ident_t& id, bool def_as_label)
{
    if (id.name_space) {
        if (id.name_space->empty()) {
            // .id: unqualified name (global)
            if (auto it = global_symbols.find(id.name); it != global_symbols.end()) {
                if (auto label = std::get_if<label_t>(it->second.get()))
                    label->fix(); // referenced global label, it must not become undefined
                return {it->second.get(), true};
            } else
                if (def_as_label && define_label(file, id.name, std::nullopt, true) &&
                    (it = global_symbols.find(id.name)) != global_symbols.end())
                {
                    return {it->second.get(), true};
                } else
                    return {nullptr, false};
        } else {
            // namespace.id: qualified name
            if (auto ns_it = file->second.name_spaces.find(*id.name_space); ns_it == file->second.name_spaces.end())
                return {nullptr, false};
            else
                file = ns_it->second;
        }
    } else {
        // id: predefined name
        if (auto it = predef_symbols.find(id.name); it != predef_symbols.end())
            return {it->second.get(), true};
    }
    // id: local name; namespace.id: qualified name
    if (auto sym_it = symbols.find(file); sym_it == symbols.end())
        throw fatal_error{std::format("File \"{}\" does not have a symbol table", file->first.string())};
    else
        if (auto it = sym_it->second.find(id.name); it != sym_it->second.end())
            return {it->second.get(), true};
        else
            if (def_as_label && define_label(file, id.name, std::nullopt, false) &&
                (it = sym_it->second.find(id.name)) != sym_it->second.end())
            {
                return {it->second.get(), true};
            } else
                return {nullptr, false};
}

assembler::parse_expr_t
assembler::parse_expr(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                      parser::id_macro_t macro_id)
{
    std::pair <parse_expr_t, std::string_view> expr = parse_expr0_or(s, file, macro_args, macro_id);
    if (!expr.first)
        return expr.first;
    if (expr.second.find_first_not_of(whitespace_chars) != std::string_view::npos)
        return std::unexpected("Unexpected characters after expression");
    return expr.first;
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr0_or(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                          parser::id_macro_t macro_id)
{
    return parse_expr_binary<&assembler::parse_expr1_xor, expr_or>(s, file, macro_args, macro_id);
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr1_xor(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                           parser::id_macro_t macro_id)
{
    return parse_expr_binary<&assembler::parse_expr2_and, expr_xor>(s, file, macro_args, macro_id);
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr2_and(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                           parser::id_macro_t macro_id)
{
    return parse_expr_binary<&assembler::parse_expr3_shift, expr_and>(s, file, macro_args, macro_id);
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr3_shift(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                             parser::id_macro_t macro_id)
{
    return parse_expr_binary<&assembler::parse_expr4_additive, expr_shl, expr_shr>(s, file, macro_args, macro_id);
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr4_additive(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                                parser::id_macro_t macro_id)
{
    return parse_expr_binary<&assembler::parse_expr5_multiplicative, expr_add, expr_sub>(s, file, macro_args, macro_id);
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr5_multiplicative(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                                      parser::id_macro_t macro_id)
{
    return parse_expr_binary<&assembler::parse_expr_unary, expr_mul, expr_div, expr_rem>(s, file, macro_args, macro_id);
}

template<assembler::parse_fun_t F, std::derived_from<assembler::expr_base> ...E>
std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr_binary(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                             parser::id_macro_t macro_id)
{
    auto result = (this->*F)(s, file, macro_args, macro_id);
    if (!result.first)
        return result;
    auto it = result.second.begin();
    while (parser::whitespace(*it))
        ++it;
    if (it == result.second.end())
        return result;
    auto branch = [&]<class T>(T*) -> bool {
        if (!std::string_view(it, result.second.end()).starts_with(T::op))
            return false;
        if (!dynamic_cast<expr_number*>(result.first->get())) {
            result =
                {std::unexpected(std::format("Unexpected '{}' after non-numeric expression", *it)), result.second};
        } else if (auto right = (this->*F)({it  + T::op.size(),  result.second.end()}, file, macro_args, macro_id);
                   !right.first)
        {
            result = std::move(right);
        } else if (!dynamic_cast<expr_number*>(right.first->get()))
            result = {std::unexpected(std::format("Unexpected non-numeric expression after '{}'", *it)), right.second};
        else
            result = {std::make_shared<T>(std::move(*result.first), std::move(*right.first)), right.second};
        return true;
    };
    (false || ... || branch(static_cast<E*>(nullptr)));
    return result;
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr_term(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                           parser::id_macro_t macro_id)
{
    auto it = s.begin();
    while (parser::whitespace(*it))
        ++it;
    s = {it, s.end()};
    if (s.empty())
        return {std::unexpected("Empty term in expression"), s};
    if (*it == '(') {
        auto inner = parse_expr0_or(s.substr(1), file, macro_args, macro_id);
        if (!inner.first)
            return inner;
        it = inner.second.begin();
        while (parser::whitespace(*it))
            ++it;
        if (it == inner.second.end() || *it != ')')
            return {std::unexpected("Missing ')' after subexpression"), s};
        return {inner.first, {++it, inner.second.end()}};
    }
    if (auto ident = parser::identifier(s, false, macro_id); ident.first) {
        if (auto ma = macro_args && !ident.first->name_space ?
            std::optional{macro_args->find(ident.first->name)} : std::nullopt; ma && *ma != macro_args->end())
        {
            return {(*ma)->second, ident.second};
        }
        auto [symbol, defined] = find_symbol(file, *ident.first, true);
        if (!symbol && defined)
            return {std::unexpected(std::format("Multiple definitions of unqualified value name \"{}\"",
                                                *ident.first)), s};
        if (!symbol)
            return {std::unexpected(std::format("Undefined symbol \"{}\"", *ident.first)), s};
        if (auto label = std::get_if<label_t>(symbol))
            return {{std::make_shared<expr_label>(*label)}, ident.second};
        else if (auto var = std::get_if<var_t>(symbol))
            return {{var->expr->fixed_clone(var->expr)}, ident.second};
        else if (std::get_if<macro_t>(symbol))
            return {std::unexpected(std::format("Reference to macro \"{}\" in expression", *ident.first)), s};
        else
            throw fatal_error{"Unexpected type of symbol in expression"};
    }
    if (auto number = parser::number_unsigned(s, false); number.first)
        return {{std::make_shared<expr_const>(number.first->val)}, number.second};
    if (auto bytes = parser::bytes(s, false); bytes.first)
        return {{std::make_shared<expr_bytes>(*bytes.first)}, bytes.second};
    return {std::unexpected("Expected symbol, constant, or parenthesized subexpression in expression"), s};
}

std::pair<assembler::parse_expr_t, std::string_view>
assembler::parse_expr_unary(std::string_view s, input::files_t::const_iterator file, macro_args_t* macro_args,
                            parser::id_macro_t macro_id)
{
    auto it = s.begin();
    while (parser::whitespace(*it))
        ++it;
    s = {it, s.end()};
    if (s.empty())
        return {std::unexpected("Empty (sub)expression"), s};
    if (*it == '~' || *it == '-') {
        auto inner = parse_expr_term(s.substr(1), file, macro_args, macro_id);
        if (!inner.first)
            return inner;
        if (!dynamic_cast<expr_number*>(inner.first->get()))
            return {std::unexpected(std::format("Unexpected non-numeric expression after '{}'", *it)), inner.second};
        switch (*it) {
        case '~':
            return {std::make_shared<expr_not>(*inner.first), inner.second};
        case '-':
            return {std::make_shared<expr_neg>(*inner.first), inner.second};
        default:
            std::unreachable();
        }
    } else
        return parse_expr_term(s, file, macro_args, macro_id);
}

std::string assembler::remove_comment(std::string_view line)
{
    std::string result{};
    result.reserve(line.size());
    bool in_char = false;
    bool in_str = false;
    for (auto it = line.begin(); it != line.end() && (in_char || in_str || *it != '#'); ++it) {
        switch (*it) {
        case '\'':
            if (in_char)
                in_char = false;
            else if (!in_str)
                in_char = true;
            break;
        case '"':
            if (in_str)
                in_str = false;
            else if (!in_char)
                in_str = true;
            break;
        case '\\':
            result.push_back(*it);
            if (it + 1 != line.end())
                ++it;
            break;
        default:
            break;
        }
        result.push_back(*it);
    }
    if (result.find_first_not_of(whitespace_chars) == std::string::npos)
        result.clear();
    return result;
}

void assembler::run()
{
    if (verbose)
        std::cerr << "Begin compilation" << std::endl;
    auto [files, top] = in.files();
    symbols.emplace(std::piecewise_construct, std::forward_as_tuple(top), std::forward_as_tuple());
    run_file(files, top);
    if (verbose)
        std::cerr << "End compilation" << std::endl;
    bool undef = false;
    for (auto&& t: symbols)
        for (auto&& s: t.second)
            if (auto l = std::get_if<label_t>(s.second.get()); l && !l->value()) {
                if (!undef) {
                    std::cerr << "Undefined labels:" << std::endl;
                    undef = true;
                }
                std::cerr << t.first->first.string() << ": " << s.first << std::endl;
            }
    bool undef_gl = false;
    for (auto&& s: global_symbols)
        if (auto l = std::get_if<label_t>(s.second.get()); l && !l->value()) {
            if (!undef_gl) {
                std::cerr << "Undefined unqualified (global) labels:" << std::endl;
                undef_gl = true;
            }
            std::cerr << '.' << s.first << std::endl;
        }
    if (undef || undef_gl) {
        std::cerr << "Cannot resolve labels in the second phase" << std::endl;
        throw silent_error{};
    }
    for (auto&& p: phase2)
        if (auto v = p.expr->eval()) {
            if (p.word)
                out.set_word(p.addr, *v);
            else
                out.set_byte(p.addr, uint8_t(*v % 256));
        } else
            throw fatal_error{"Cannot evaluate an expression in the second phase"};
}

void assembler::run_lines(const input::files_t& files, input::files_t::const_iterator current,
                          std::span<const std::string> full_text, std::span<const std::string> text,
                          size_t macro_idx, macro_args_t* macro_args, size_t macro_level)
{
    std::string line_prefix = std::string(4 * macro_level, ' ');
    std::string_view macro_prefix = macro_args ? "MACRO "sv : ""sv;
    size_t cur_macro = macro_args ? ++max_macro : 0; // for label$
    size_t last_macro = 0; // for label$$
    for (auto [full_it, text_it] = std::pair{full_text.begin(), text.begin()};
         full_it != full_text.end() && text_it != text.end();
         ++full_it, ++text_it
    ) {
        // Add source line to text output
        size_t line_num = size_t(full_it - current->second.full_text.begin()) + 1;
        if (!full_it->empty() && full_it->front() != '#') {
            out.add_src_line(current->first, line_num, *full_it, line_prefix, macro_prefix);
            macro_prefix = ""sv;
        } else
            out.last_line = line_num;
        if (text_it->empty())
            continue;
        // Split to label: cmd args...
        auto parts = split(*text_it);
        // Process label
        if (!parts.label.empty()) {
            auto id = parser::identifier(parts.label, true, {{cur_macro, last_macro}});
            if (!id.first || id.first->name_space) {
                std::cerr << src_pos(current->first, line_num) <<
                    "Expected identifier without namespace as the label" << std::endl;
                throw silent_error{};
            }
            if (!define_label(current, std::string(id.first->name), cur_addr, false)) {
                std::cerr << src_pos(current->first, line_num) << "Symbol \"" << id.first->name <<
                    "\" already defined" << std::endl;
                throw silent_error{};
            }
        }
        if (parts.cmd.empty())
            continue;
        // Process directives
        if (parts.cmd == "$addr"sv) {
            if (parts.args.size() != 1) {
                std::cerr << src_pos(current->first, line_num) << "$addr requires one argument" << std::endl;
                throw silent_error{};
            }
            if (auto e = parse_expr(parts.args[0], current, macro_args, {{cur_macro, last_macro}}); !e) {
                std::cerr << src_pos(current->first, line_num) << "Invalid argument: " << e.error() << std::endl;
                throw silent_error{};
            } else {
                if (auto v = (*e)->eval()) {
                    cur_addr = *v;
                    out.add_txt_line(std::format("$addr {:#06x}", cur_addr), line_prefix);
                } else {
                    std::cerr << src_pos(current->first, line_num) << "Cannot evaluate $addr in the first phase" <<
                        std::endl;
                    throw silent_error{};
                }
            }
        } else if (parts.cmd == "$const"sv) {
            if (parts.args.size() != 2) {
                std::cerr << src_pos(current->first, line_num) << "$const requires two arguments" << std::endl;
                throw silent_error{};
            }
            auto id = parser::identifier(parts.args[0], true, {{cur_macro, last_macro}});
            if (!id.first || id.first->name_space) {
                std::cerr << src_pos(current->first, line_num) <<
                    "Expected identifier without namespace as the first argument of $const" << std::endl;
                throw silent_error{};
            }
            auto e = parse_expr(parts.args[1], current, macro_args, {{cur_macro, last_macro}});
            if (!e) {
                std::cerr << src_pos(current->first, line_num) << "Invalid expression in $const: " << e.error() <<
                    std::endl;
                throw silent_error{};
            }
            if (!define_const(current, id.first->name, std::move(*e))) {
                std::cerr << src_pos(current->first, line_num) << "Symbol \"" << id.first->name <<
                    "\" already defined" << std::endl;
                throw silent_error{};
            }
        } else if (parts.cmd == "$data_b"sv) {
            std::vector<uint8_t> bytes{};
            auto start_addr = cur_addr;
            for (size_t i = 0; auto&& a: parts.args) {
                ++i;
                if (auto b = parse_expr(a, current, macro_args, {{cur_macro, last_macro}}); !b) {
                    std::cerr << src_pos(current->first, line_num) << "Invalid argument " << i << " of $data_b: " <<
                        b.error() << std::endl;
                    throw silent_error{};
                } else
                    if (auto v = (*b)->eval_bytes()) {
                        bytes.append_range(*v);
                        cur_addr += bytes.size();
                    } else {
                        bytes.push_back(0);
                        phase2.push_back({.expr = std::move(*b), .addr = cur_addr, .word = false});
                        ++cur_addr;
                    }
            }
            out.add_bytes(start_addr, bytes, ""sv, line_prefix);
        } else if (parts.cmd == "$data_w"sv) {
            std::vector<uint8_t> bytes{};
            auto start_addr = cur_addr;
            for (size_t i = 0; auto&& a: parts.args) {
                ++i;
                if (auto w = parse_expr(a, current, macro_args, {{cur_macro, last_macro}}); !w) {
                    std::cerr << src_pos(current->first, line_num) << "Invalid argument " << i << " of $data_w: " <<
                        w.error() << std::endl;
                    throw silent_error{};
                } else {
                    if (auto v = (*w)->eval()) {
                        bytes.push_back(uint8_t(*v % 256));
                        bytes.push_back(uint8_t(*v / 256));
                    } else {
                        bytes.push_back(0);
                        bytes.push_back(0);
                        phase2.push_back({.expr = std::move(*w), .addr = cur_addr, .word = true});
                    }
                    cur_addr += 2;
                }
            }
            out.add_bytes(start_addr, bytes, ""sv, line_prefix);
        } else if (parts.cmd == "$macro"sv) {
            if (macro_args) {
                std::cerr << src_pos(current->first, line_num) << "Nested macro definition not allowed" << std::endl;
                throw silent_error{};
            }
            if (parts.args.empty()) {
                std::cerr << src_pos(current->first, line_num) << "Missing macro name in $macro" << std::endl;
                throw silent_error{};
            }
            auto id = parser::identifier(parts.args[0], true);
            if (!id.first || id.first->name_space) {
                std::cerr << src_pos(current->first, line_num) <<
                    "Expected identifier without namespace as the macro name in $macro" << std::endl;
                throw silent_error{};
            }
            std::vector<std::string> params;
            for (size_t i = 1; i < parts.args.size(); ++i) {
                auto p = parser::identifier(parts.args[i], true);
                if (!p.first || p.first->name_space) {
                    std::cerr << src_pos(current->first, line_num) <<
                        "Expected identifier without namespace as parameter " << i << " of $macro" << std::endl;
                    throw silent_error{};
                }
                params.push_back(std::move(p.first->name));
            }
            for (auto [full_begin, text_begin] = std::pair{++full_it, ++text_it};
                 full_it != full_text.end() && text_it != text.end();
                 ++full_it, ++text_it)
            {
                if (auto parts = split(*text_it); parts.cmd == "$end_macro"sv) {
                    if (!define_macro(current, id.first->name, {full_begin, full_it},
                                      {text_begin, text_it}, std::move(params)))
                    {
                        std::cerr << src_pos(current->first, line_num) <<
                            "Symbol \"" << id.first->name << "\" already defined" << std::endl;
                        throw silent_error{};
                    }
                    out.last_line = line_num;
                    break;
                }
            }
            if (full_it == full_text.end() || text_it == text.end()) {
                std::cerr << src_pos(current->first, line_num) <<
                    "Missing $end_macro at the end of macro definition" << std::endl;
                throw silent_error{};
            }
        } else if (parts.cmd == "$use"sv) {
            if (parts.args.size() != 2)
                throw fatal_error{"Invalid $use in assembler::run_file"};
            auto id_ns = parser::identifier(parts.args[0], true);
            if (!id_ns.first || id_ns.first->name_space)
                throw fatal_error{"Invalid namespace in $use in assembler::run_file"};
            if (auto ns_it = current->second.name_spaces.find(id_ns.first->name);
                ns_it == current->second.name_spaces.end())
            {
                throw fatal_error{std::format("Namespace {} not registered in input::files", id_ns.first->name)};
            } else
                if (auto sym_it = symbols.find(ns_it->second); sym_it == symbols.end()) {
                    symbols.emplace(std::piecewise_construct,
                                    std::forward_as_tuple(ns_it->second), std::forward_as_tuple());
                    run_file(files, ns_it->second);
                }
        } else if (parts.cmd.front() == '$') {
            std::cerr << src_pos(current->first, line_num) << "Unknown directive \"" << parts.cmd << '"' << std::endl;
            throw silent_error{};
        } else if (auto id = parser::identifier(parts.cmd, true, {{cur_macro, last_macro}}); !id.first) {
            std::cerr << src_pos(current->first, line_num) << id.first.error() << std::endl;
            throw silent_error{};
        } else {
            // Expand macros
            auto [symbol, defined] = find_symbol(current, *id.first);
            if (!symbol && defined) {
                std::cerr << src_pos(current->first, line_num) << "Multiple definitions of unqualified macro name \"" <<
                    *id.first << '"' << std::endl;
                throw silent_error{};
            }
            if (symbol) {
                if (const macro_t* macro = std::get_if<macro_t>(symbol)) {
                    if (macro->order > macro_idx) {
                        std::cerr << src_pos(current->first, line_num) << "Macro \"" << *id.first <<
                            "\" not defined before the current macro" << std::endl;
                        throw silent_error{};
                    }
                    if (macro->params.size() != parts.args.size()) {
                        std::cerr << src_pos(current->first, line_num) << "Macro \"" << *id.first << "\" expects " <<
                            macro->params.size() << " arguments, " << parts.args.size() << " passed" << std::endl;
                        throw silent_error{};
                    }
                    macro_args_t args{};
                    for (size_t i = 0; i < parts.args.size(); ++i) {
                        if (auto a = parse_expr(parts.args[i], current, macro_args, {{cur_macro, last_macro}}); !a) {
                            std::cerr << src_pos(current->first, line_num) << "Invalid argument " << (i + 1) <<
                                " of macro: " << a.error() << std::endl;
                            throw silent_error{};
                        } else
                            args.emplace(macro->params[i], std::move(*a));
                    }
                    try {
                        run_lines(files, macro->file, macro->full_replace, macro->replace, macro->order, &args,
                                  macro_level + 1);
                        // On macro level 0, we cannot strip 2 spaces from (empty) line_prefix
                        macro_prefix = macro_level > 0 ? "    END_MACRO "sv : "  END_MACRO "sv;
                    } catch (const silent_error&) {
                        std::cerr << src_pos(current->first, line_num) << "Error in macro expansion" << std::endl;
                        throw;
                    }
                } else {
                    std::cerr << src_pos(current->first, line_num) << "Symbol \"" << *id.first << "\" is not a macro" <<
                        std::endl;
                    throw silent_error{};
                }
            } else if (!id.first->name_space) {
                // Generate instructions
                if (parts.args.size() != 2) {
                    std::cerr << src_pos(current->first, line_num) << "Instruction requires two arguments" << std::endl;
                    throw silent_error{};
                }
                auto instr = opcodes.find(id.first->name);
                if (instr == opcodes.end()) {
                    std::cerr << src_pos(current->first, line_num) << "Unknown instruction \"" << id.first->name <<
                        '"' << std::endl;
                    throw silent_error{};
                }
                auto dst = parse_expr(parts.args[0], current, macro_args, {{cur_macro, last_macro}});
                if (!dst) {
                    std::cerr << src_pos(current->first, line_num) << "Invalid destination register of instruction: " <<
                        dst.error() << std::endl;
                    throw silent_error{};
                }
                auto dst_reg = (*dst)->eval_reg();
                if (!dst_reg || dst_reg->second != instr->second.dst_csr) {
                    std::cerr << src_pos(current->first, line_num) << "Invalid destination register of instruction" <<
                        std::endl;
                    throw silent_error{};
                }
                auto src = parse_expr(parts.args[1], current, macro_args, {{cur_macro, last_macro}});
                if (!src) {
                    std::cerr << src_pos(current->first, line_num) << "Invalid source register of instruction: " <<
                        src.error() << std::endl;
                    throw silent_error{};
                }
                auto src_reg = (*src)->eval_reg();
                if (!src_reg || src_reg->second != instr->second.src_csr) {
                    std::cerr << src_pos(current->first, line_num) << "Invalid source register of instruction" <<
                        std::endl;
                    throw silent_error{};
                }
                std::array<uint8_t, 2> bytes{};
                bytes[0] = instr->second.opcode;
                bytes[1] = uint8_t(dst_reg->first << 4U) | (src_reg->first);
                out.add_bytes(cur_addr, bytes,
                              std::format("{} {}, {}", id.first->name, (*dst)->eval_reg_str(), (*src)->eval_reg_str()),
                              line_prefix);
                cur_addr += 2;
            } else {
                    // Unknown name
                std::cerr << src_pos(current->first, line_num) << "Name \"" << *id.first <<
                    "\" is not a known instruction or macro" << std::endl;
                throw silent_error{};
            }
        }
    }
}
                          
void assembler::run_file(const input::files_t& files, input::files_t::const_iterator current)
{
    if (verbose)
        std::cerr << "Compiling file \"" << current->first.string() << '"' << std::endl;
    run_lines(files, current, current->second.full_text, current->second.text);
    if (verbose)
        std::cerr << "Done file \"" << current->first.string() << '"' << std::endl;
}

assembler::line_t assembler::split(std::string_view line)
{
    line_t result{};
    // Find (optional) label
    auto label_b = line.begin();
    while (label_b != line.end() && parser::whitespace(*label_b))
        ++label_b;
    auto label_e = label_b;
    while (label_e != line.end() && !parser::whitespace(*label_e) && *label_e != ':')
        ++label_e;
    auto colon_it = label_e;
    while (colon_it != line.end() && parser::whitespace(*colon_it))
        ++colon_it;
    std::string_view::iterator cmd_b{};
    if (colon_it != line.end() && *colon_it == ':') {
        cmd_b = colon_it + 1;
    } else {
        cmd_b = label_b; // no label, start at the first non-whitespace
        label_e = label_b;
    }
    // Find command (instruction or directive)
    while (cmd_b != line.end() && parser::whitespace(*cmd_b))
        ++cmd_b;
    auto cmd_e = cmd_b;
    while (cmd_e != line.end() && !parser::whitespace(*cmd_e))
        ++cmd_e;
    result.label = {label_b, label_e};
    result.cmd = {cmd_b, cmd_e};
    // Split arguments
    for (auto arg_b = cmd_e; arg_b != line.end();) {
        while (arg_b != line.end() && parser::whitespace(*arg_b))
            ++ arg_b;
        auto arg_e = arg_b;
        bool in_char = false;
        bool in_str = false;
        for (; arg_e != line.end() && (in_char || in_str || *arg_e != ','); ++arg_e)
             switch (*arg_e) {
             case '\'':
                 if (in_char)
                     in_char = false;
                 else if (!in_str)
                     in_char = true;
                 break;
             case '"':
                 if (in_str)
                     in_str = false;
                 else if (!in_char)
                     in_str = true;
                 break;
             case '\\':
                 if (arg_e + 1 != line.end())
                     ++arg_e;
                 break;
             default:
                 break;
             }
        if (arg_e != line.end() || arg_e != arg_b) {
            // comma or non-empty argument after last comma
            result.args.emplace_back(arg_b, arg_e);
            for (auto& arg = result.args.back(); !arg.empty() && parser::whitespace(arg.back());)
                arg.remove_suffix(1);
        }
        arg_b = arg_e; // end or comma
        if (arg_b != line.end())
            ++arg_b; // skip comma
    }
    return result;
}

/*** Command line processing *************************************************/

class cmdline_args: public cmdline_args_base {
public:
    cmdline_args(int argc, char* argv[]);
    std::string usage();
    [[nodiscard]] sfs::path input_file() const {
        return _verbose ? args[2] : args[1];
    }
    [[nodiscard]] bool verbose() const { return _verbose; }
private:
    bool _verbose = false;
};

cmdline_args::cmdline_args(int argc, char* argv[]):
    cmdline_args_base(argc, argv)
{
    try {
        if (args.size() < 2 || args.size() > 3)
            throw invalid_cmdline_args{};
        if (args[1] == "-v"sv)
            _verbose = true;
        if (args.size() != (_verbose ? 3 : 2))
            throw invalid_cmdline_args{};
    } catch (const invalid_cmdline_args&) {
        std::cerr << usage() << '\n';
        throw;
    }
}

std::string cmdline_args::usage()
{
    return cmdline_args_base::usage().append(R"([-v] input_file.s

-v ... verbose output
)"sv);
}

/*** Entry point *************************************************************/

int main(int argc, char* argv[])
{
    try {
        cmdline_args args{argc, argv};
        input in(args.input_file(), args.verbose());
        output out(args.input_file(), args.verbose());
        assembler as(in, out, args.verbose());
        as.run();
        out.write();
        return EXIT_SUCCESS;
    } catch (const fatal_error& e) {
        std::cerr << e.what() << std::endl;
    } catch (const silent_error&) {
        ; // already reported
    } catch (const std::exception& e) {
        std::cerr << "Unhandled exception: " << e.what() << std::endl;
    } catch (...) {
        std::cerr << "Unhandled unknown exception" << std::endl;
    }
    return EXIT_FAILURE;
}
