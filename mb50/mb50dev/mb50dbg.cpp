// MB50DEV debugger

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <span>
#include <system_error>

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

/*** The main processing loop ************************************************/

// Returns false if the debugger should terminate, true otherwise
bool run_cmd(cdi& mb50, script_history& log, std::string_view cmd)
{
    // TODO
    (void)mb50;

    if (cmd == "quit"sv || cmd == "q"sv)
        return false;
    else {
        log.output() << "Unknown command";
        log.endl();
    }
    return true;
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
