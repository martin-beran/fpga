// MB50 common declarations included by both mb50as and mb50dbg

#include <cstdint>
#include <expected>
#include <optional>
#include <string>
#include <string_view>
#include <type_traits>

using namespace std::string_literals; // NOLINT
using namespace std::string_view_literals; // NOLINT

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

// Create an expected result
template<class T> result_t<std::remove_reference_t<T>> expected(T&& v, std::string_view s)
{
    return {typename result_t<std::remove_reference_t<T>>::first_type{std::forward<T>(v)}, s};
}

// Check a whitespace character
bool whitespace(char c)
{
    return whitespace_chars.find(c) != std::string_view::npos;
}

// Skip whitespace and return if at least one character was skipped
result_t<bool> whitespace(std::string_view s, bool all = true);

// 8 or 16 bit number
struct number_t {
    uint16_t val = 0; // unsigned value
    bool word = false; // false=byte (8 bits), true=word (16 bits)
    bool negative = false; // number entered as negative (val is two's complement)
};

// Parses a number from a string. See documentation for assembler and debugger
// number syntax.
result_t<number_t> number(std::string_view s, bool all);

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

result_t<number_t> character(std::string_view s, bool all)
{
    if (s.empty() || s.front() != '\'')
        return result_t<number_t>{std::unexpected{"Expected character constant"s}, s};
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
                return expected(result, s.substr(i));
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
            if (!all)
                return expected(result, s.substr(i));
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
                return expected(result, s.substr(i));
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
            if (!all)
                return expected(result, s.substr(i));
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
                return expected(result, s.substr(i));
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
            if (!all)
                return expected(result, s.substr(i));
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
                return expected(result, s);
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
        if (n == 1)
            result.val = uint8_t(c);
        else {
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
            return expected(l > 0, s.substr(l));
        else
            return {std::unexpected{"Expected whitespace"s}, s};
    } else
        return expected(l > 0, s.substr(s.size()));
}

} // namespace parser
