# Fish Shell Configuration & Aliases for MacBookPro10,2 (macOS 15 Sequoia OCLP)
# Location: ~/.config/fish/config.fish

# 1. Faster path search and suppress linker warnings
set -gx PATH /usr/bin /bin /usr/local/bin /usr/sbin /sbin
set -g fish_greeting ""
set -gx DYLD_USE_CLOSURES 0
set -gx DYLD_PRINT_WARNINGS 0
set -gx NSGL_DISABLE_QUARTZ 1

# Direct dynamic linker to Cryptex cache to prevent lookup storms
set -gx DYLD_SHARED_CACHE_DIR /System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld
set -gx DYLD_SHARED_CACHE_DONT_VALIDATE 1

# 2. Lightweight prompt (Zero synchronous git overhead and no 1Hz clock wakeups)
function fish_prompt
    set -l last_folder (basename (prompt_pwd))
    echo -n (set_color blue)"$last_folder "(set_color green)'$ '(set_color normal)
end

function fish_right_prompt
    # Intentionally empty to avoid CPU wakeups
end

# 3. Interactive Shell Boost
function boost
    set -l pid $fish_pid
    sudo renice -n -15 -p $pid
    echo (set_color green)"[OK] Fish Shell (PID: $pid) elevated to priority -15"(set_color normal)
end

# 4. MacBoost CLI Integration
function macboost
    command macboost $argv
end

function optimizemac
    command macboost $argv
end

# 5. Energy and Thermal Pressure Inspector
function energy-hogs
    echo (set_color -o red)"--- Highest CPU Consumers ---"(set_color normal)
    top -l 1 -n 12 -o cpu -stats pid,command,cpu,state | sed -n '/PID/,$p' | awk '$3 > 0.0 || $2 == "COMMAND"'
    
    echo ""
    echo (set_color cyan)"--- Thermal State & Memory ---"(set_color normal)
    
    set -l therm_speed (pmset -g therm | grep "CPU_Speed_Limit" | awk '{print $NF}')
    if test -n "$therm_speed"
        set -l col (test "$therm_speed" = "100"; and echo green; or echo yellow)
        echo "CPU Speed Limit: "(set_color $col)"$therm_speed%"(set_color normal)
    else
        echo "CPU Speed Limit: "(set_color green)"100% (Nominal)"(set_color normal)
    end

    set -l free_pages (sysctl -n vm.page_free_count)
    set -l free_mb (math -s0 "($free_pages * 4096) / 1048576")
    echo "Direct Free Memory: $free_mb MB"
end

# 6. Intel Ivy Bridge C-State Residency Diagnostics
function macboost-cstates
    echo (set_color cyan)"--- C-State Residency Snapshot (Intel Ivy Bridge) ---"(set_color normal)
    sudo powermetrics -n 1 -i 1000 -s cpu_power | grep -E "C-state|Residency|package"
end
