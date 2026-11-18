proc read_count {backend} {
    if {[gets $backend count] < 0} {
        error "The counter process closed its output."
    }
    if {![string is integer -strict $count]} {
        error "Unexpected counter response: $count"
    }
    return $count
}

proc launch_backend {executable} {
    set channel [open [list | [file normalize $executable]] r+]
    fconfigure $channel -buffering line -encoding utf-8
    return $channel
}

proc dispatch {command} {
    global backend count status

    if {[catch {
        puts $backend $command
        set count [read_count $backend]
    } message]} {
        set status $message
        .controls.increment state disabled
        .controls.reset state disabled
    }
}

proc close_window {} {
    global backend

    if {[catch {close $backend} message]} {
        puts stderr $message
    }
    destroy .
}

if {$argc != 1} {
    puts stderr "Usage: wish counter.tcl /path/to/counter_tk"
    exit 2
}

if {[catch {
    set backend [launch_backend [lindex $argv 0]]
    set count [read_count $backend]
} message]} {
    puts stderr $message
    tk_messageBox -icon error -title "Counter" -message $message
    exit 1
}

set status ""
wm title . "Counter"
wm resizable . 0 0
wm protocol . WM_DELETE_WINDOW close_window

ttk::label .count -textvariable count -width 20 -anchor center
ttk::frame .controls
ttk::button .controls.increment -text "Increment" -command {dispatch increment}
ttk::button .controls.reset -text "Reset" -command {dispatch reset}
ttk::label .status -textvariable status -anchor center
pack .controls.increment .controls.reset -side left -padx 4
pack .count .controls .status -padx 16 -pady 8
focus .controls.increment
