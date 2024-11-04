// MB50 common declarations included by both mb50as and mb50dbg

#include <cstdint>
#include <expected>
#include <string>
#include <string_view>

using namespace std::string_literals; // NOLINT
using namespace std::string_view_literals; // NOLINT

// Return a printable character, replace a non-printable character
char display_ascii(uint8_t c, char replace)
{
    return c >= 32 && c < 127 ? char(c) : replace;
}

namespace parser {

// Parsing result: a value if succesful, error message on error, and the remaining part of the string
template<class T> using result_t = std::pair<std::expected<T, std::string>, std::string_view>;

template<class T> result_t<T> expected(T&& v, std::string_view s)
{
    return {typename result_t<T>::first_type{std::forward<T>(v)}, s};
}

// 8 or 16 bit number
struct number_t {
    uint16_t val = 0; // unsigned value
    bool word = false; // false=byte (8 bits), true=word (16 bits)
    bool negative = false; // number entered as negative (val is two's complement)
};

// Parses a number from a string. See documentation for assembler and debugger
// number syntax.
result_t<number_t> number(std::string_view s);

result_t<number_t> character(std::string_view s);
result_t<number_t> number_bin(std::string_view s);
result_t<number_t> number_dec(std::string_view s);
result_t<number_t> number_hex(std::string_view s);

result_t<number_t> number(std::string_view s)
{
    if (s.starts_with("0x"sv)) {
        if (auto n = number_hex(s.substr(2)); n.first)
            return n;
        else
            return {n.first, s};
    } else if (s.starts_with("0b"sv)) {
        if (auto n = number_bin(s.substr(2)); n.first)
            return n;
        else
            return {n.first, s};
    } else if (s.starts_with("-"sv)) {
        if (auto n = number_dec(s.substr(1)); n.first) {
            n.first->val = uint16_t(-n.first->val);
            n.first->negative = true;
            return n;
        } else
            return {n.first, s};
    } else if (s.starts_with("'"sv))
        return character(s);
    else
        return number_dec(s);
}

result_t<number_t> character(std::string_view s)
{
    // TODO
    return {std::unexpected{"Expected character constant"s}, s};
}

result_t<number_t> number_bin(std::string_view s)
{
    // TODO
    return {std::unexpected{"Expected binary number"s}, s};
}

result_t<number_t> number_dec(std::string_view s)
{
    // TODO
    return {std::unexpected{"Expected decimal number"s}, s};
}

result_t<number_t> number_hex(std::string_view s)
{
    // TODO
    return {std::unexpected{"Expected hexadecimal number"s}, s};
}

} // namespace parser
