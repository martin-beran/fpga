// MB50DEV assembler

#include "mb50common.hpp"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <ios>
#include <iostream>
#include <map>
#include <ranges>
#include <stack>
#include <tuple>
#include <utility>

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
    void add_bytes(uint16_t addr, std::span<uint8_t> bytes, std::string_view instr = {});
    // Stores a source line for text output file
    void add_src_line(const sfs::path& file, size_t line, std::string text);
    void add_txt_line(std::string_view text);
    void set_byte(uint16_t addr, uint8_t byte);
    void set_word(uint16_t addr, uint16_t word);
    // Writes all output files
    void write();
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
    assembler(input& in, output& out, bool verbose): in(in), out(out), verbose(verbose) {}
    void run();
    static std::string remove_comment(std::string_view line);
    // Expects a line without comment
    static line_t split(std::string_view line);
private:
    // expression base
    struct as_expr {
        as_expr() = default;
        as_expr(const as_expr&) = delete;
        as_expr(as_expr&&) = delete;
        as_expr& operator=(const as_expr&) = delete;
        as_expr& operator=(as_expr&&) = delete;
        virtual ~as_expr() = default;
        virtual std::optional<uint16_t> eval() {
            return std::nullopt;
        }
        // returns a sequence of bytes; after nullopt in the first phase, length 1 is expected for the second phase
        virtual std::optional<std::vector<uint8_t>> eval_bytes() {
            if (auto val = eval())
                return {{uint8_t(*val % 256U)}};
            else
                return std::nullopt;
        }
    };
    // second phase of expression evaluation
    struct phase2_t {
        std::shared_ptr<as_expr> expr; // evaluate this expression
        uint16_t addr; // store value here
        bool word; // false = byte, true = word
    };
    struct label_t {
        std::optional<uint16_t> value;
    };
    struct const_t {
        std::optional<uint16_t> value;
        std::shared_ptr<as_expr> expr;
    };
    struct macro_t {
        std::vector<std::string> params; // names of parameters of this macro
        input::files_t::const_iterator file; // file containing the macro definition
        std::span<std::string> replace; // replacement text
        size_t order; // ordering of macro definitions
    };
    using symbol_t = std::variant<label_t, const_t, macro_t>;
    using symbol_table_t = std::map<std::string, symbol_t>;
    using macro_args_t = std::map<std::string, std::shared_ptr<as_expr>>;
    void run_file(const input::files_t& files, input::files_t::const_iterator current);
    // macro_args != nullptr when expanding a macro; cur_macro is for label$
    void run_lines(const input::files_t& files, input::files_t::const_iterator current,
                   std::span<const std::string> full_text, std::span<const std::string> text,
                   size_t first_line = 1, macro_args_t* macro_args = nullptr);
    // false if symbol name already defined, true otherwise
    bool define_const(input::files_t::const_iterator file, std::string name, std::shared_ptr<assembler::as_expr> expr);
    // false if symbol name already defined, true otherwise
    bool define_label(input::files_t::const_iterator file, std::string name, uint16_t addr);
    static std::expected<std::shared_ptr<as_expr>, std::string> parse_expr(std::string_view s);
    input& in;
    output& out;
    bool verbose;
    std::map<input::files_t::const_iterator, symbol_table_t, decltype([](auto&& a, auto&& b){ return &*a < &*b; })>
        symbols;
    size_t max_macro = 0; // for label$
    uint16_t cur_addr = 0; // current output address
    std::vector<phase2_t> phase2;
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
        std::cerr << "Reading file \"" << it->first << '"' << std::endl;
    it->second.processed = true;
    if (std::ifstream ifs{it->first}; !ifs) {
        std::cerr << "Cannot read file \"" << it->first << '"' << std::endl;
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

void output::add_bytes(uint16_t addr, std::span<uint8_t> bytes, std::string_view instr)
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
        out_text.push_back({.text = std::format("; {:04x}: {}", addr, instr)});
    out_text.push_back({.text = std::format("; {:04x}: $data_b", addr), .bytes = {addr_begin, addr_end}});
}

void output::add_src_line(const sfs::path& file, size_t line, std::string text)
{
    if (file != last_file) {
        out_text.push_back({.text = std::format("; {}:{}", file.string(), line)});
        last_file = file;
    }
    out_text.push_back({.text = std::move(text)});
}

void output::add_txt_line(std::string_view text)
{
    out_text.push_back({.text = std::format("; {}", text)});
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
        std::cerr << "Writing file \"" << file.string() << '"' << std::endl;
    ofs.open(file, std::ios_base::binary | std::ios_base::trunc);
    if (!ofs)
        throw fatal_error(std::format("Cannot write binary output file \"{}\"", file.string()));
    ofs << std::format("\n", start_addr);
    if (out_size > 0)
        ofs.write(reinterpret_cast<const char*>(out_bin.data() + start_addr), out_size);
    ofs.close();
    if (!ofs)
        throw fatal_error(std::format("Error writing binary output file \"{}\"", file.string()));

    out_file = file;
    out_file.replace_extension(".mif");
    if (verbose)
        std::cerr << "Writing file \"" << file.string() << '"' << std::endl;
    ofs.open(file, std::ios_base::binary | std::ios_base::trunc);
    if (!ofs)
        throw fatal_error(std::format("Cannot write MIF output file \"{}\"", file.string()));
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
        throw fatal_error(std::format("Error writing MIF output file \"{}\"", file.string()));

    out_file = file;
    out_file.replace_extension(".out");
    if (verbose)
        std::cerr << "Writing file \"" << file.string() << '"' << std::endl;
    ofs.open(file, std::ios_base::trunc);
    if (!ofs)
        throw fatal_error(std::format("Cannot write text output file \"{}\"", file.string()));
    for (auto&&l: out_text) {
        ofs << l.text;
        std::string delim = " "s;
        for (auto b: l.bytes) {
            ofs << delim << std::format("{:#02x}", b);
            delim = ", "s;
        }
        ofs << '\n';
    }
    ofs.close();
    if (!ofs)
        throw fatal_error(std::format("Error writing text output file \"{}\"", file.string()));
}

/*** assembler ***************************************************************/

bool assembler::define_const(input::files_t::const_iterator file, std::string name,
                             std::shared_ptr<assembler::as_expr> expr)
{
    if (auto it = symbols.find(file); it == symbols.end())
        throw fatal_error("Parsed file not in assembler::symbols");
    else
        return it->second.emplace(std::move(name), const_t{.value = expr->eval(), .expr = std::move(expr)}).second;
}

bool assembler::define_label(input::files_t::const_iterator file, std::string name, uint16_t addr)
{
    if (auto it = symbols.find(file); it == symbols.end())
        throw fatal_error("Parsed file not in assembler::symbols");
    else
        return it->second.emplace(std::move(name), label_t{.value = addr}).second;
}

std::expected<std::shared_ptr<assembler::as_expr>, std::string> assembler::parse_expr(std::string_view s)
{
    (void)s;
    // TODO
    return nullptr;
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
    run_file(files, top);
    if (verbose)
        std::cerr << "End compilation" << std::endl;
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
                          size_t first_line, macro_args_t* macro_args)
{
    size_t cur_macro = macro_args ? ++max_macro : 0; // for label$
    size_t last_macro = 0; // for label$$
    for (auto [full_it, text_it] = std::pair{full_text.begin(), text.begin()};
         full_it != full_text.end() && text_it != text.end();
         ++full_it, ++text_it
    ) {
        // Add source line to text output
        size_t line_num = size_t(full_it - current->second.full_text.begin()) + first_line;
        if (!full_it->empty() && full_it->front() != '#')
            out.add_src_line(current->first, line_num, *full_it);
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
            if (!define_label(current, std::string(id.first->name), cur_addr)) {
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
            if (auto e = parse_expr(parts.args[0]); !e) {
                std::cerr << src_pos(current->first, line_num) << "Invalid argument: " << e.error() << std::endl;
                throw silent_error{};
            } else {
                if (auto v = (*e)->eval()) {
                    cur_addr = *v;
                    out.add_txt_line(std::format("$addr {}", cur_addr));
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
            auto e = parse_expr(parts.args[1]);
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
                if (auto b = parse_expr(a); !b) {
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
            out.add_bytes(start_addr, bytes);
        } else if (parts.cmd == "$data_w"sv) {
            std::vector<uint8_t> bytes{};
            auto start_addr = cur_addr;
            for (size_t i = 0; auto&& a: parts.args) {
                ++i;
                if (auto w = parse_expr(a); !w) {
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
            out.add_bytes(start_addr, bytes);
        } else if (parts.cmd == "$macro"sv) {
            if (macro_args) {
                std::cerr << src_pos(current->first, line_num) << "Nested macro definition not allowed" << std::endl;
                throw silent_error{};
            }
            // TODO
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
        }
        // Expand macros
        // Generate instructions
    }
}
                          
void assembler::run_file(const input::files_t& files, input::files_t::const_iterator current)
{
    if (verbose)
        std::cerr << "Compiling file \"" << current->first << '"' << std::endl;
    run_lines(files, current, current->second.full_text, current->second.text);
    if (verbose)
        std::cerr << "Done file \"" << current->first << '"' << std::endl;
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
    } else
        cmd_b = label_b; // no label, start at the first non-whitespace
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
        else if (args.size() != 2)
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
    } catch (const std::exception& e) {
        std::cerr << "Unhandled exception: " << e.what() << std::endl;
    } catch (...) {
        std::cerr << "Unhandled unknown exception" << std::endl;
    }
    return EXIT_FAILURE;
}
