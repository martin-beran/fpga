// MB50DEV debugger

#include "mb50common.hpp"

#include <algorithm>
#include <cstdlib>
#include <filesystem>
#include <format>
#include <fstream>
#include <iostream>
#include <map>
#include <span>
#include <system_error>
#include <vector>

#include <sys/select.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

/*** Error handling **********************************************************/

// An exception that prints an error message and terminates the program
class fatal_error: public std::runtime_error {
public:
    explicit fatal_error(std::string_view msg):
        std::runtime_error{"Fatal error: "s.append(msg)} {}
};

/*** Saving interaction script and command history ***************************/

class script_history {
public:
    // Starts appending to a script file
    void start_script(const std::filesystem::path& file);
    // Stops appending to a script file
    void stop_script();
    // Start appending to a history file
    void start_history(const std::filesystem::path& file);
    // Stops appending to a history file
    void stop_history();
    // Writes an input line to script and history, prefixed with "> " in script, s expected without newline
    void input(std::string_view s);
    // Writes "< " to ofs, should be called at the beginning of each output line
    script_history& output();
    // Writes newline and flushes ofs, should be called at the end of each
    // output line.
    void endl();
    // Writes to std::cout and to ofs (if open)
    template<class T> script_history& operator<<(const T& v);
private:
    std::ofstream script;
    std::ofstream history;
};

void script_history::start_script(const std::filesystem::path& file)
{
    stop_script();
    script.open(file, std::ios_base::app);
    if (!script)
        std::cerr << "Cannot open script file \"" << file.string() << "\"" << std::endl;
}

void script_history::stop_script()
{
    script.close();
}

void script_history::start_history(const std::filesystem::path& file)
{
    stop_history();
    history.open(file, std::ios_base::app);
    if (!history)
        std::cerr << "Cannot open history file \"" << file.string() << "\"" << std::endl;
}

void script_history::stop_history()
{
    history.close();
}

void script_history::input(std::string_view s)
{
    if (script)
        script << "> " << s << std::endl;
    if (history)
        history << s << std::endl;
}

script_history& script_history::output()
{
    if (script)
        script << "< ";
    return *this;
}

void script_history::endl()
{
    std::cout << std::endl;
    if (script)
        script << std::endl;
}

template<class T> script_history& script_history::operator<<(const T& v)
{
    std::cout << v;
    if (script)
        script << v;
    return *this;
}

/*** MB50 CDI ****************************************************************/

// Request codes correspond to Req* constants in cdi.vhd
enum class cdi_request: uint8_t {
    csr_rd = 0x06,
    csr_wr = 0x07,
    execute = 0x03,
    mem_rd = 0x08,
    mem_wr = 0x09,
    reg_rd = 0x04,
    reg_wr = 0x05,
    status = 0x01,
    step = 0x02,
    zero_unused = 0x00,
};

// Response codes correspond to Resp* constants in cdi.vhd
enum class cdi_response: uint8_t {
    mem_rd = 0x05,
    mem_wr = 0x06,
    reg_rd = 0x03,
    reg_wr = 0x04,
    status = 0x02,
    unknown_req = 0x01,
    zero_unused = 0x00,
};

std::string errno_message()
{
    return std::error_code(errno, std::generic_category()).message();
}

class cdi {
public:
    explicit cdi(script_history& log, const std::filesystem::path& p);
    cdi(const cdi&) = delete;
    cdi(cdi&&) = delete;
    ~cdi();
    cdi& operator=(const cdi&) = delete;
    cdi& operator=(cdi&&) = delete;
    void cmd_execute();
    std::vector<uint8_t> cmd_memory(uint16_t addr, uint16_t size);
    void cmd_memory(uint16_t addr, const std::vector<uint8_t>& data);
    uint16_t cmd_register(uint8_t r, bool csr);
    void cmd_register(uint8_t r, bool csr, uint16_t v);
    void cmd_status();
    void cmd_step();
private:
    [[nodiscard]] std::vector<uint8_t> read_serial(size_t n) const;
    void write_serial(std::span<const uint8_t> data) const;
    static void check_response(uint8_t resp, cdi_response expected);
    // expect_exe_resp=true if response from an uninterrupted cdi_request::execute is expected
    void read_status(bool expect_exe_resp = false);
    script_history& log;
    int tty_fd = -1;
};

cdi::cdi(script_history& log, const std::filesystem::path& p):
    log(log), tty_fd{open(p.c_str(), O_RDWR)}
{
    if (tty_fd < 0)
        throw fatal_error("Cannot open serial port device \""s.append(p.string()).append("\": ").
                          append(errno_message()));
    termios t{};
    if (tcgetattr(tty_fd, &t) != 0)
        throw fatal_error("Cannot get serial port configuration: "s. append(errno_message()));
    cfmakeraw(&t);
    if (cfsetispeed(&t, B115200) != 0 || cfsetospeed(&t, B115200) != 0)
        throw fatal_error("Cannot set serial port speed: "s.append(errno_message()));
    if (tcsetattr(tty_fd, TCSANOW, &t) != 0)
        throw fatal_error("Cannot configure serial port: "s. append(errno_message()));
}

cdi::~cdi()
{
    if (tty_fd >= 0)
        close(tty_fd);
}

void cdi::check_response(uint8_t resp, cdi_response expected)
{
    if (resp != static_cast<uint8_t>(expected))
        throw fatal_error(std::format("Invalid response {:#04x}, expected {:#04x}",
                                      resp, static_cast<uint8_t>(expected)));
}

void cdi::cmd_execute()
{
    std::array req{
        static_cast<uint8_t>(cdi_request::execute),
    };
    std::cout << "Executing program, press Enter to break" << std::endl;
    write_serial(req);
    fd_set fds;
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    FD_SET(tty_fd, &fds);
    if (select(tty_fd + 1, &fds, nullptr, nullptr, nullptr) < 0)
        throw fatal_error("Failed call to select(2): "s.append(errno_message()));
    if (FD_ISSET(STDIN_FILENO, &fds)) {
        std::string line;
        std::getline(std::cin, line);
        cmd_status();
    } else // tty_fd ready
        read_status(true);
}

std::vector<uint8_t> cdi::cmd_memory(uint16_t addr, uint16_t size)
{
    size_t result_sz = size == 0 ? 0xffff : size;
    std::array req{
        static_cast<uint8_t>(cdi_request::mem_rd),
            uint8_t(addr % 256),
            uint8_t(addr / 256),
            uint8_t(size % 256),
            uint8_t(size / 256),
    };
    write_serial(req);
    auto resp = read_serial(1 + result_sz);
    check_response(resp[0], cdi_response::mem_rd);
    resp.erase(resp.begin());
    return resp;
}

void cdi::cmd_memory(uint16_t addr, const std::vector<uint8_t>& data)
{
    std::array req{
        static_cast<uint8_t>(cdi_request::mem_wr),
        uint8_t(addr % 256),
        uint8_t(addr / 256),
        uint8_t(data.size() % 256),
        uint8_t(data.size() / 256),
    };
    write_serial(req);
    write_serial(data);
    auto resp = read_serial(1);
    check_response(resp[0], cdi_response::mem_wr);
}

uint16_t cdi::cmd_register(uint8_t r, bool csr)
{
    std::array req{
        static_cast<uint8_t>(csr ? cdi_request::csr_rd : cdi_request::reg_rd),
        r,
    };
    write_serial(req);
    auto resp = read_serial(3);
    check_response(resp[0], cdi_response::reg_rd);
    return uint16_t(resp[1] + (resp[2] << 8U));
}

void cdi::cmd_register(uint8_t r, bool csr, uint16_t v)
{
    std::array req{
        static_cast<uint8_t>(csr ? cdi_request::csr_wr : cdi_request::reg_wr),
        r,
        uint8_t(v % 256),
        uint8_t(v / 256),
    };
    write_serial(req);
    auto resp = read_serial(1);
    check_response(resp[0], cdi_response::reg_wr);
}

void cdi::cmd_status()
{
    std::array req{
        static_cast<uint8_t>(cdi_request::status),
    };
    write_serial(req);
    read_status();
}

void cdi::cmd_step()
{
    std::array req{
        static_cast<uint8_t>(cdi_request::step),
    };
    write_serial(req);
    read_status();
}

std::vector<uint8_t> cdi::read_serial(size_t n) const
{
    std::vector<uint8_t> result(n);
    for (size_t i = 0; i < result.size();)
        if (auto r = read(tty_fd, result.data() + i, result.size() - i); r < 0)
            throw fatal_error("Cannot read from serial port: "s.append(errno_message()));
        else
            i += size_t(r);
    return result;
}

void cdi::read_status(bool expect_exe_resp)
{
    bool halted = false;
    bool exe_resp = false;
    uint16_t pc = 0x0000;
    do {
        auto resp = read_serial(4);
        check_response(resp[0], cdi_response::status);
        halted = (resp[1] & 0b0000'0001U) != 0;
        exe_resp = (resp[1] & 0b0000'0010U) != 0;
        pc = uint16_t(resp[2] + (resp[3] << 8U));
    } while (!expect_exe_resp && exe_resp);
    log.output() << std::format("Ready r15(pc)={:#06x} halted={}", pc, halted);
    log.endl();
}

void cdi::write_serial(std::span<const uint8_t> data) const
{
    if (write(tty_fd, data.data(), data.size()) < 0)
        throw fatal_error("Cannot write to serial port: "s.append(errno_message()));
}

/*** Processing debugger commands ********************************************/

bool do_file(cdi& mb50, script_history& log, const std::filesystem::path& file);

// Base class for all commands
class command {
public:
    command() = default;
    command(const command&) = delete;
    command(command&&) = delete;
    virtual ~command() = default;
    command& operator=(const command&) = delete;
    command& operator=(command&&) = delete;
    virtual std::vector<std::string_view> aliases();
    virtual std::string_view help_args();
    virtual std::string_view help();
    // Returns false if the debugger should terminate, true otherwise
    virtual bool operator()(cdi& mb50, script_history& log, std::string_view args);
};

std::vector<std::string_view> command::aliases()
{
    return {};
}

std::string_view command::help_args()
{
    return "";
}

std::string_view command::help()
{
    return "Not implemented.";
}

bool command::operator()(cdi&, script_history& log, std::string_view)
{
    log.output() << "Not implemented";
    log.endl();
    return true;
}

// Mapping from commands names to implementations
class command_table {
public:
    static command_table& get();
    void help(std::string_view name);
    void help();
    // Returns false if the debugger should terminate, true otherwise
    bool run_cmd(cdi& mb50, script_history& log, std::string_view name, std::string_view args);
private:
    struct command_t {
        std::shared_ptr<command> impl;
        bool alias = false;
        command_t make_alias() {
            return command_t{impl, true};
        }
    };
    command_table();
    std::map<std::string_view, command_t> commands;
};

// Command csr
class cmd_csr: public command {
public:
    std::string_view help_args() override { return R"([NAME] [VALUE])"; }
    std::string_view help() override { return R"(Like register, but operates on csr0...csr15.)"; }
    bool operator()(cdi& mb50, script_history&log, std::string_view args) override;
protected:
    struct reg_name {
        std::string_view index;
        std::string_view name;
        std::string_view alias;
        std::string_view display;
    };
    static constexpr char ascii_replace = ' ';
    void display(script_history& log, uint8_t r, uint16_t v);
    virtual const std::vector<reg_name>& registers();
    virtual bool csr() { return true; }
};

void cmd_csr::display(script_history& log, uint8_t r, uint16_t v)
{
    log.output() <<
        std::format("{:7}  {:#06x}  {:5d}  {:+6d}  {:3d}  {:3d}  {:c}{:c}  0b{:04b}_{:04b}_{:04b}_{:04b}",
                    registers().at(r).display,
                    v, v, int16_t(v), v % 256, v / 256,
                    display_ascii(uint8_t(v % 256), ascii_replace), display_ascii(v / 256, ascii_replace),
                    (v & 0xf000U) >> 12U, (v & 0x0f00U) >> 8U, (v & 0x00f0U) >> 4U, v & 0x000fU);
    log.endl();
}

bool cmd_csr::operator()(cdi& mb50, script_history& log, std::string_view args)
{
    constexpr size_t npos = std::string_view::npos;
    std::string_view name{};
    std::string_view value{};
    size_t name_e = args.find_first_of(whitespace_chars);
    name = args.substr(0, name_e);
    std::optional<uint8_t> reg_idx{};
    if (!name.empty()) {
        reg_idx = uint8_t(
            std::ranges::find_if(registers(),
                                 [name](auto&& v) { return name == v.index || name == v.name || name == v.alias; }) -
            registers().begin());
        if (reg_idx >= registers().size()) {
            log.output() << "Unknown register name \"" << name << "\"";
            log.endl();
            return true;
        }
    }
    if (name_e != npos)
        if (size_t value_b = args.find_first_not_of(whitespace_chars, name_e); value_b != npos)
            value = args.substr(value_b);
    if (value.empty()) {
        log.output() << "REG      HEX     DEC    SIGNED  LO   HI   LH    ---- KCEI oscz 3210";
                      // r15(pc)  0x04d2  01234  +01234  210  004      0b0000_0100_1101_0010
        log.endl();
        if (reg_idx)
            display(log, *reg_idx, mb50.cmd_register(*reg_idx, csr()));
        else
            for (uint8_t i = 0; size_t(i) < registers().size(); ++i)
                display(log, i, mb50.cmd_register(i, csr()));
    } else {
        if (auto v = parser::number(value, true); v.first)
            mb50.cmd_register(reg_idx.value(), csr(), v.first->val); // NOLINT(bugprone-unchecked-optional-access)
        else {
            log.output() << "Invalid value: " << v.first.error();
            log.endl();
        }
    }

    return true;
}

const std::vector<cmd_csr::reg_name>& cmd_csr::registers()
{
    static std::vector<reg_name> r{
        {"0", "csr0", "csr0", "csr0"}, {"1", "csr1", "csr1", "csr1"},
        {"2", "csr2", "csr2", "csr2"}, {"3", "csr3", "csr3", "csr3"},
        {"4", "csr4", "csr4", "csr4"}, {"5", "csr5", "csr5", "csr5"},
        {"6", "csr6", "csr6", "csr6"}, {"7", "csr7", "csr7", "csr7"},
        {"8", "csr8", "csr8", "csr8"}, {"9", "csr9", "csr9", "csr9"},
        {"10", "csr10", "csr10", "csr10"}, {"11", "csr11", "csr11", "csr11"},
        {"12", "csr12", "csr12", "csr12"}, {"13", "csr13", "csr13", "csr13"},
        {"14", "csr14", "csr14", "csr14"}, {"15", "csr15", "csr15", "csr15"},
    };
    return r;
}

// Command do
class cmd_do: public command {
public:
    std::string_view help_args() override { return "FILE"; }
    std::string_view help() override { return R"(Describe available commands.)"; }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_do::operator()(cdi& mb50, script_history& log, std::string_view args)
{
    return do_file(mb50, log, args);
}

// Command execute
class cmd_execute: public command {
public:
    std::vector<std::string_view> aliases() override { return {"exe", "x"}; }
    std::string_view help() override {
        return R"(Run the program. Program execution is interrupted by entering a newline.
Any characters on the line before the newline are ignored.)";
    }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_execute::operator()(cdi& mb50, script_history&, std::string_view)
{
    mb50.cmd_execute();
    return true;
}

// Command help
class cmd_help: public command {
public:
    std::vector<std::string_view> aliases() override { return {"h", "?"}; }
    std::string_view help_args() override { return "[COMMAND]"; }
    std::string_view help() override { return R"(Describe available commands.)"; }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_help::operator()(cdi&, script_history&, std::string_view args)
{
    if (args.empty())
        command_table::get().help();
    else
        command_table::get().help(args);
    return true;
}

// Command history
class cmd_history: public command {
public:
    std::string_view help_args() override { return "[FILE]"; }
    std::string_view help() override {
        return R"(If called with a FILE name, start appending all executed commands to the end
of the file. If called without a file name, stop recording commands.)";
    }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_history::operator()(cdi&, script_history& log, std::string_view args)
{
    if (args.empty())
        log.stop_history();
    else
        log.start_history(args);
    return true;
}

// Command step
class cmd_step: public command {
public:
    std::vector<std::string_view> aliases() override { return {"s"}; }
    std::string_view help() override { return R"(Execute a single instruction.)"; }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_step::operator()(cdi& mb50, script_history&, std::string_view)
{
    mb50.cmd_step();
    return true;
}

// Command quit
class cmd_quit: public command {
public:
    std::vector<std::string_view> aliases() override { return {"q"}; }
    std::string_view help() override { return R"(Terminate the debugger.)"; }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_quit::operator()(cdi&, script_history& log, std::string_view)
{
    log.output() << "Quit!";
    log.endl();
    return false;
}

// Command register
class cmd_register: public cmd_csr {
public:
    std::vector<std::string_view> aliases() override { return {"reg", "r"}; }
    std::string_view help() override {
        return R"(Display or set values of registers. Without arguments, it shows values of all
registers r0...r15. With NAME, only a single register is shown, where NAME is
a register name or a standard register alias (r0...r15, pc, f, ia, ca, sp).
With also VALUE, the value is stored in the register.)";
    }
protected:
    const std::vector<reg_name>& registers() override;
    bool csr() override { return false; }
};

const std::vector<cmd_csr::reg_name>& cmd_register::registers()
{
    static std::vector<reg_name> r{
        {"0", "r0", "r0", "r0"}, {"1", "r1", "r1", "r1"},
        {"2", "r2", "r2", "r2"}, {"3", "r3", "r3", "r3"},
        {"4", "r4", "r4", "r4"}, {"5", "r5", "r5", "r5"},
        {"6", "r6", "r6", "r6"}, {"7", "r7", "r7", "r7"},
        {"8", "r8", "r8", "r8"}, {"9", "r9", "r9", "r9"},
        {"10", "r10", "r10", "r10"}, {"11", "r11", "sp", "r11(sp)"},
        {"12", "r12", "ca", "r12(ca)"}, {"13", "r13", "ia", "r13(ia)"},
        {"14", "r14", "f", "r14(f)"}, {"15", "r15", "pc", "r15(pc)"},
    };
    return r;
}

// Command script
class cmd_script: public command {
public:
    std::string_view help_args() override { return "[FILE]"; }
    std::string_view help() override {
        return R"(If called with a FILE name, start appending all user input and debugger output
to the end of the file. If called without a file name, stop recording.)";
    }
    bool operator()(cdi& mb50, script_history& log, std::string_view args) override;
};

bool cmd_script::operator()(cdi&, script_history& log, std::string_view args)
{
    if (args.empty())
        log.stop_script();
    else
        log.start_script(args);
    return true;
}

// Implementation of command_table

command_table::command_table():
    commands{
        {"break", {std::make_shared<command>()}},
        {"csr", {std::make_shared<cmd_csr>()}},
        {"do", {std::make_shared<cmd_do>()}},
        {"dump", {std::make_shared<command>()}},
        {"dumpd", {std::make_shared<command>()}},
        {"dumpw", {std::make_shared<command>()}},
        {"dumpwd", {std::make_shared<command>()}},
        {"execute", {std::make_shared<cmd_execute>()}},
        {"help", {std::make_shared<cmd_help>()}},
        {"history", {std::make_shared<cmd_history>()}},
        {"load", {std::make_shared<command>()}},
        {"memset", {std::make_shared<command>()}},
        {"quit", {std::make_shared<cmd_quit>()}},
        {"register", {std::make_shared<cmd_register>()}},
        {"save", {std::make_shared<command>()}},
        {"script", {std::make_shared<cmd_script>()}},
        {"step", {std::make_shared<cmd_step>()}},
        {"watch", {std::make_shared<command>()}},
    }
{
    std::vector<std::pair<std::string_view, command_t>> aliases;
    for (auto&& c: commands)
        for (auto&& a: c.second.impl->aliases())
            aliases.emplace_back(a, c.second.make_alias());
    for (auto&& a: aliases)
        commands[a.first] = std::move(a.second);
}

command_table& command_table::get()
{
    static command_table t{};
    return t;
}

void command_table::help(std::string_view name)
{
    if (auto cmd = commands.find(name); cmd != commands.end()) {
        std::cout << cmd->first;
        if (auto args = cmd->second.impl->help_args(); !args.empty())
            std::cout << ' ' << args;
        std::cout << '\n';
        if (auto aliases = cmd->second.impl->aliases(); !aliases.empty()) {
            std::string_view delim = "aliases: ";
            for (auto&& a: aliases) {
                std::cout << delim << a;
                delim = ", ";
            }
            std::cout << '\n';
        }
        std::cout << cmd->second.impl->help() << '\n' << std::endl;
    } else
        std::cout << "Unknown command" << std::endl;
}

void command_table::help()
{
    for (auto&& cmd: commands)
        if (!cmd.second.alias)
            help(cmd.first);
}

bool command_table::run_cmd(cdi& mb50, script_history& log, std::string_view name, std::string_view args)
{
    if (auto hnd = commands.find(name); hnd != commands.end())
        return (*hnd->second.impl)(mb50, log, args);
    else {
        log.output() << "Unknown command";
        log.endl();
        return true;
    }
}

/*** The main processing loop ************************************************/

// Returns false if the debugger should terminate, true otherwise
bool run_cmd(cdi& mb50, script_history& log, std::string_view cmd)
{
    constexpr size_t npos = std::string_view::npos;
    size_t args_i = cmd.find_first_of(whitespace_chars);
    std::string_view name = cmd.substr(0, args_i);
    if (args_i != npos)
        args_i = cmd.find_first_not_of(whitespace_chars, args_i + 1);
    std::string_view args = args_i != npos ? cmd.substr(args_i) : std::string_view{};
    args = args.substr(0, args.find_first_of(whitespace_chars));
    return command_table::get().run_cmd(mb50, log, name, args);
}

bool do_file(cdi& mb50, script_history& log, const std::filesystem::path& file)
{
    log.output() << "BEGIN " << file.string();
    log.endl();
    if (std::ifstream ifs{file}) {
        for (std::string line; std::getline(ifs, line);)
            if (!run_cmd(mb50, log, line))
                return false;
    } else {
        log.output() << "Cannot open DO file \"" << file.string() << "\"";
        log.endl();
    }
    log.output() << "END " << file.string();
    log.endl();
    return true;
}

void run(cdi& mb50, script_history& log, std::optional<std::string_view> init_file)
{
    mb50.cmd_status();
    if (init_file)
        if (!do_file(mb50, log, *init_file))
            return;
    for (std::string line;;) {
        std::cout << "> ";
        if (!std::getline(std::cin, line)) {
            std::cout << std::endl;
            return;
        }
        log.input(line);
        if (!run_cmd(mb50, log, line))
            return;
    }
}

/*** Command line processing *************************************************/

class cmdline_args {
public:
    cmdline_args(int argc, char* argv[]);
    std::string usage();
    [[nodiscard]] bool help() const { return _help; }
    [[nodiscard]] std::string_view tty() const { return args[1]; }
    [[nodiscard]] std::optional<std::string_view> init_file() const {
        return args.size() > 2 ? std::optional{args[2]} : std::nullopt;
    }
private:
    class invalid_cmdline_args: public fatal_error {
    public:
        invalid_cmdline_args(): fatal_error("Invalid command line arguments") {}
    };
    std::span<const char*> args;
    bool _help = false;
};

cmdline_args::cmdline_args(int argc, char* argv[]):
    args{const_cast<const char**>(argv), size_t(argc)}
{
    try {
        if (args.size() < 2 || args.size() > 3)
            throw invalid_cmdline_args{};
        if (args[1] == "-h"sv || args[1] == "--help"sv)
            _help = true;
    } catch (const invalid_cmdline_args&) {
        std::cerr << usage() << '\n';
        throw;
    }
}

std::string cmdline_args::usage()
{
    return "\n"s.append(args[0]).append(R"( tty [init_file]
)"sv).append(args[0]).append( R"( {-h|--help}

tty       ... serial port device for communication with the target computer
init_file ... optional file containing initial commands executed before
              entering the interactive mode
-h|--help ... print this help message and exit
)"sv);
}

/*** Entry point *************************************************************/

int main(int argc, char* argv[])
{
    try {
        cmdline_args args{argc, argv};
        if (args.help()) {
            std::cerr << args.usage() << std::endl;
        } else {
            script_history log;
            cdi mb50(log, args.tty());
            run(mb50, log, args.init_file());
        }
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
