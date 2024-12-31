// MB50 common declarations included by both mb50as and mb50dbg

#include <cstdint>
#include <expected>
#include <format>
#include <optional>
#include <ostream>
#include <ranges>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

using namespace std::string_literals; // NOLINT
using namespace std::string_view_literals; // NOLINT

/*** Error handling **********************************************************/

// An exception that prints an error message and terminates the program
class fatal_error: public std::runtime_error {
public:
    explicit fatal_error(std::string_view msg):
        std::runtime_error{"Fatal error: "s.append(msg)} {}
};

// An exception that assumes an already printed error message and terminates the program
class silent_error: public std::runtime_error {
public:
    silent_error(): runtime_error("") {}
};

/*** Parsing text ************************************************************/

// Whitespace characters
constexpr std::string_view whitespace_chars = " \t";

// Return a printable character, replace a non-printable character
char display_ascii(uint8_t c, char replace)
{
    return c >= 32 && c < 127 ? char(c) : replace;
}

namespace parser {

// Parsing result: a value if succesful, error message on error, and the
// remaining part of the string. If not all input to a parsing function is
// consumed, the expected value is returned if function parameter all == true,
// the unexpected value is returned if all == false.
template<class T> using result_t = std::pair<std::expected<T, std::string>, std::string_view>;

// Check a whitespace character
bool whitespace(char c)
{
    return whitespace_chars.find(c) != std::string_view::npos;
}

// Skip whitespace and return if at least one character was skipped
result_t<bool> whitespace(std::string_view s, bool all = true);

// An identifier with an optional namespace
struct ident_t {
    std::optional<std::string> name_space; // nullopt for local, empty for unqualified (global)
    std::string name; // nonempty
};

std::ostream& operator<<(std::ostream& os, ident_t id)
{
    if (id.name_space)
        os << *id.name_space << '.' << id.name;
    else
        os << id.name;
    return os;
}

} // namespace parser

template<> struct std::formatter<parser::ident_t, char> {
    template<class ParseCtx> constexpr ParseCtx::iterator parse(ParseCtx& ctx) {
        if (ctx.begin() == ctx.end() || *ctx.begin() == '}')
            return ctx.begin();
        throw std::format_error("Invalid format args for parser::ident_t");
    }
    template<class FmtCtx> FmtCtx::iterator format(const parser::ident_t& val, FmtCtx& ctx) const {
        auto out = ctx.out();
        if (val.name_space) {
            out = std::ranges::copy(*val.name_space, out).out;
            *out++ = '.';
        }
        return std::ranges::copy(val.name, out).out;
    }
};

namespace parser {

// Values of replacement numbers for $ and $$ in names of labels and constants
using id_macro_t = std::optional<std::pair<size_t, size_t>>;

// Parses an identifier
result_t<ident_t> identifier(std::string_view s, bool all, id_macro_t macro = std::nullopt);

// 8 or 16 bit number
struct number_t {
    uint16_t val = 0; // unsigned value
    bool word = false; // false=byte (8 bits), true=word (16 bits)
    bool negative = false; // number entered as negative (val is two's complement)
};

// Parses an unsigned (non-negative) number from a string
result_t<number_t> number_unsigned(std::string_view s, bool all);

// Parses a number from a string. See documentation for assembler and debugger number syntax.
result_t<number_t> number(std::string_view s, bool all);

// Parses a sequence of bytes from a string. It can be one or two bytes (little
// endian) parsed by number(), or a string constant in double quotes.
result_t<std::vector<uint8_t>> bytes(std::string_view s, bool all);

std::optional<uint8_t> digit_bin(char c, bool all);
std::optional<uint8_t> digit_dec(char c, bool all);
std::optional<uint8_t> digit_hex(char c, bool all);

result_t<number_t> character(std::string_view s, bool all);
result_t<number_t> number_bin(std::string_view s, bool all);
result_t<number_t> number_dec(std::string_view s, bool all);
result_t<number_t> number_hex(std::string_view s, bool all);

result_t<number_t> str_char(std::string_view s, bool all, char quote);

std::optional<uint8_t> digit_bin(char c)
{
    if (c >= '0' && c <= '1')
        return c - '0';
    else
        return std::nullopt;
}

std::optional<uint8_t> digit_dec(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    else
        return std::nullopt;
}

std::optional<uint8_t> digit_hex(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    else if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    else if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    else
        return std::nullopt;
}

result_t<std::vector<uint8_t>> bytes(std::string_view s, bool all)
{
    if (s.starts_with("\""sv)) {
        auto s_orig = s;
        s = s.substr(1);
        std::vector<uint8_t> data;
        while (!s.empty() && s.front() != '"')
            if (auto v = str_char(s, false, '"'); v.first) {
                data.push_back(uint8_t(v.first->val));
                s = v.second;
            } else
                return {std::unexpected{v.first.error()}, s_orig};
        if (s.empty())
            return {std::unexpected{"Missing terminating quote in string constant"}, s_orig};
        s = s.substr(1); // s.front() == '"'
        if (!all || s.empty())
            return {{std::move(data)}, s};
        else
            return {std::unexpected{"Expected string constant"}, s_orig};
    } else {
        if (auto v = number(s, all); v.first) {
            if (v.first->word)
                return {{{uint8_t(v.first->val % 256), uint8_t(v.first->val / 256)}}, v.second};
            else
                return {{{uint8_t(v.first->val % 256)}}, v.second};
        } else
            return {std::unexpected{v.first.error()}, s};
    }
}

result_t<ident_t> identifier(std::string_view s, bool all, id_macro_t macro)
{
    ident_t result{};
    for (size_t i = 0; i <= s.size(); ++i) {
        if (i == s.size()) {
            if (!result.name.empty())
                return {result, s.substr(i)};
            else
                break;
        }
        if ((s[i] >= 'A' && s[i] <= 'Z') || (s[i] >= 'a' && s[i] <= 'z') ||
            (!result.name.empty() && (s[i] >= '0' && s[i] <= '9')) || s[i] == '_')
        {
            result.name.push_back(s[i]);
        } else if (s[i] == '.' && !result.name_space) {
            result.name_space = std::move(result.name);
            result.name.clear();
        } else if (macro && s[i] == '$') {
            if (result.name.empty())
                break;
            if (i < s.size() - 1 && s[i + 1] == '$') {
                result.name += std::to_string(macro->second);
                ++i;
            } else
                result.name += std::to_string(macro->first);
            ++i;
            if (!all || i == s.size())
                return {result, s.substr(i)};
            else
                break;
        } else {
            if (!result.name.empty() && !all)
                return {result, s.substr(i)};
            else
                break;
        }
    }
    return {std::unexpected{"Expected identifier"s}, s};
}

result_t<number_t> number(std::string_view s, bool all)
{
    if (s.starts_with("0x"sv) || s.starts_with("0X"sv)) {
        if (auto n = number_hex(s.substr(2), all); n.first)
            return n;
        else
            return {n.first, s};
    } else if (s.starts_with("0b"sv) || s.starts_with("0B"sv)) {
        if (auto n = number_bin(s.substr(2), all); n.first)
            return n;
        else
            return {n.first, s};
    } else if (s.starts_with("-"sv)) {
        if (auto n = number_dec(s.substr(1), all); n.first) {
            n.first->val = uint16_t(-n.first->val);
            n.first->negative = true;
            return n;
        } else
            return {n.first, s};
    } else if (s.starts_with("'"sv))
        return character(s, all);
    else
        return number_dec(s, all);
}

result_t<number_t> number_unsigned(std::string_view s, bool all)
{
    auto result  = number(s, all);
    if (result.first && result.first->negative)
        return {std::unexpected{"Negative number not allowed"s}, s};
    return result;
}

result_t<number_t> character(std::string_view s, bool all)
{
    if (s.empty() || s.front() != '\'')
        return {std::unexpected{"Expected character constant"s}, s};
    if (auto c = str_char(s.substr(1), all, '\''); c.first)
        return c;
    else
        return {c.first, s};
}

result_t<number_t> number_bin(std::string_view s, bool all)
{
    number_t result{};
    int n = 0;
    for (size_t i = 0; i <= s.size(); ++i) {
        if (i == s.size()) {
            if (n > 0)
                return {result, s.substr(i)};
            else
                break;
        }
        if (auto d = digit_bin(s[i]); d) {
            result.val = 2 * result.val + *d;
            if (++n > 8)
                result.word = true;
            if (n > 16)
                break;
        } else if (i == 0 || s[i] != '_') {
            if (i > 0 && !all)
                return {result, s.substr(i)};
            else
                break;
        }
    }
    return {std::unexpected{"Expected binary number"s}, s};
}

result_t<number_t> number_dec(std::string_view s, bool all)
{
    number_t result{};
    int n = 0;
    uint32_t v = 0;
    for (size_t i = 0; i <= s.size(); ++i) {
        if (i == s.size()) {
            if (n > 0)
                return {result, s.substr(i)};
            else
                break;
        }
        if (auto d = digit_dec(s[i]); d) {
            result.val = uint16_t(v = 10 * v + *d);
            if (++n > 3 || v > 0xff)
                result.word = true;
            if (v > 0xffff)
                break;
        } else if (i == 0 || s[i] != '_') {
            if (i > 0 && !all)
                return {result, s.substr(i)};
            else
                break;
        }
    }
    return {std::unexpected{"Expected decimal number"s}, s};
}

result_t<number_t> number_hex(std::string_view s, bool all)
{
    number_t result{};
    int n = 0;
    for (size_t i = 0; i <= s.size(); ++i) {
        if (i == s.size()) {
            if (n > 0)
                return {result, s.substr(i)};
            else
                break;
        }
        if (auto d = digit_hex(s[i]); d) {
            result.val = 16 * result.val + *d;
            if (++n > 2)
                result.word = true;
            if (n > 4)
                break;
        } else if (i == 0 || s[i] != '_') {
            if (i > 0 && !all)
                return {result, s.substr(i)};
            else
                break;
        }
    }
    return {std::unexpected{"Expected hexadecimal number"s}, s};
}

result_t<number_t> str_char(std::string_view s, bool all, char quote)
{
    auto error = [s](){ return result_t<number_t>{std::unexpected{"Expected character constant"s}, s}; };
    number_t result{};
    int n = 0;
    for (; !s.empty(); s = s.substr(1)) {
        if (s.front() == quote) {
            s = s.substr(1);
            if (!all || s.empty())
                return {result, s};
            else
                return error();
        }
        if (n++ > 2)
            return error();
        char c = '\0';
        if (s[0] == '\\') {
            s = s.substr(1);
            if (s.empty())
                return error();
            switch (s.front()) {
            case '0':
                c = '\0';
                break;
            case 't':
                c = '\t';
                break;
            case '\n':
                c = '\n';
                break;
            case '\r':
                c = '\r';
                break;
            case '"':
                c = '"';
                break;
            case '\'':
                c = '\'';
                break;
            case '\\':
                c = '\\';
                break;
            case 'x':
            case 'X':
                if (s.size() < 3)
                    return error();
                if (auto [d1, d0] = std::pair{digit_hex(s[1]), digit_hex(s[2])}; d1 && d0)
                    c = char(16 * *d1 + *d0);
                s = s.substr(2);
                break;
            default:
                return error();
            }
        } else
            c = s.front();
        if (n == 1) {
            result.val = uint8_t(c);
            if (quote == '"') // used to get one character in a string in double quotes
                return {result, s.substr(1)};
        } else {
            result.val |= unsigned(c) << 8U;
            result.word = true;
        }
    }
    return error();
}

result_t<bool> whitespace(std::string_view s, bool all)
{
    if (auto l = s.find_first_not_of(whitespace_chars); l != std::string_view::npos) {
        if (!all)
            return {l > 0, s.substr(l)};
        else
            return {std::unexpected{"Expected whitespace"s}, s};
    } else
        return {l > 0, s.substr(s.size())};
}

} // namespace parser

/*** Command line processing *************************************************/

class cmdline_args_base {
protected:
    cmdline_args_base(int argc, char* argv[]);
    std::string usage();
    class invalid_cmdline_args: public fatal_error {
    public:
        invalid_cmdline_args(): fatal_error("Invalid command line arguments") {}
    };
    std::span<const char*> args;
};

cmdline_args_base::cmdline_args_base(int argc, char* argv[]):
    args{const_cast<const char**>(argv), size_t(argc)}
{
}

std::string cmdline_args_base::usage()
{
    return "\n"s.append(args[0]).append(R"( )"sv);
}
