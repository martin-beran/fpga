// MB50DEV debugger

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <map>
#include <optional>
#include <span>
#include <system_error>
#include <vector>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

using namespace std::string_literals;
using namespace std::string_view_literals;

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

class cdi {
public:
    explicit cdi(const std::filesystem::path& p);
    cdi(const cdi&) = delete;
    cdi(cdi&&) = delete;
    ~cdi();
    cdi& operator=(const cdi&) = delete;
    cdi& operator=(cdi&&) = delete;
    void cmd_status();
private:
    int tty_fd = -1;
};

cdi::cdi(const std::filesystem::path& p):
    tty_fd{open(p.c_str(), O_RDWR)}
{
    if (tty_fd < 0)
        throw fatal_error("Cannot open serial port device \""s.append(p.string()).append("\": ").
                          append(std::error_code(errno, std::generic_category()).message()));
    termios t{};
    cfmakeraw(&t);
    if (cfsetispeed(&t, B115200) != 0 || cfsetospeed(&t, B115200) != 0)
        throw fatal_error("Cannot set serial port speed: "s.
                          append(std::error_code(errno, std::generic_category()).message()));
    if (tcsetattr(tty_fd, TCSANOW, &t) != 0)
        throw fatal_error("Cannot configure serial port: "s.
                          append(std::error_code(errno, std::generic_category()).message()));
}

cdi::~cdi()
{
    if (tty_fd >= 0)
        close(tty_fd);
}

void cdi::cmd_status()
{
}

/*** Processing debugger commands ********************************************/

constexpr std::string_view whitespace = " \t";

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
        {"csr", {std::make_shared<command>()}},
        {"do", {std::make_shared<cmd_do>()}},
        {"dump", {std::make_shared<command>()}},
        {"dumpd", {std::make_shared<command>()}},
        {"dumpw", {std::make_shared<command>()}},
        {"dumpwd", {std::make_shared<command>()}},
        {"execute", {std::make_shared<command>()}},
        {"help", {std::make_shared<cmd_help>()}},
        {"history", {std::make_shared<cmd_history>()}},
        {"load", {std::make_shared<command>()}},
        {"memset", {std::make_shared<command>()}},
        {"quit", {std::make_shared<cmd_quit>()}},
        {"register", {std::make_shared<command>()}},
        {"save", {std::make_shared<command>()}},
        {"script", {std::make_shared<cmd_script>()}},
        {"step", {std::make_shared<command>()}},
        {"trace", {std::make_shared<command>()}},
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
    size_t args_i = cmd.find_first_of(whitespace);
    std::string_view name = cmd.substr(0, args_i);
    if (args_i != npos)
        args_i = cmd.find_first_not_of(whitespace, args_i + 1);
    std::string_view args = args_i != npos ? cmd.substr(args_i) : std::string_view{};
    args = args.substr(0, args.find_first_of(whitespace));
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
            cdi mb50(args.tty());
            script_history log;
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
