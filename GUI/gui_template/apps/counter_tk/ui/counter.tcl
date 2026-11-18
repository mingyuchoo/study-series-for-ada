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
        update_controls
        if {$command eq "reset"} {
            focus .controls.increment
        }
    } message]} {
        set status $message
        .status configure -style Error.TLabel
        .controls.increment state disabled
        .controls.reset state disabled
    }
}

proc update_controls {} {
    global count status

    .status configure -style Status.TLabel
    if {$count == 999} {
        set status "Maximum reached (999). Reset to start again."
        .controls.increment state disabled
        focus .controls.reset
    } else {
        set status "Ready when you are."
        .controls.increment state !disabled
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

ttk::style theme use clam
font create CounterBody -family [font actual TkDefaultFont -family] -size 11
font create CounterHeading -family [font actual CounterBody -family] -size 20 -weight bold
font create CounterValue -family [font actual CounterBody -family] -size 56 -weight bold
font create CounterSmall -family [font actual CounterBody -family] -size 10
ttk::style configure . -font CounterBody -background #f4f6fa -foreground #0f172a
ttk::style configure Heading.TLabel -font CounterHeading
ttk::style configure Subtitle.TLabel -foreground #475569
ttk::style configure Card.TFrame -background #ffffff
ttk::style configure Caption.TLabel -background #ffffff -foreground #475569 -font CounterSmall
ttk::style configure Count.TLabel -background #ffffff -font CounterValue
ttk::style configure Status.TLabel -foreground #475569 -font CounterSmall
ttk::style configure Error.TLabel -foreground #b91c1c -font CounterSmall
ttk::style configure TButton -padding {16 12} -background #ffffff -borderwidth 1 -relief flat
ttk::style map TButton -background {pressed #e2e8f0 active #eaf0f8} \
    -bordercolor {focus #2563eb !focus #cbd5e1} -lightcolor {focus #2563eb !focus #cbd5e1} \
    -darkcolor {focus #2563eb !focus #cbd5e1}
ttk::style configure Primary.TButton -background #2563eb -foreground #ffffff
ttk::style map Primary.TButton \
    -background {disabled #e2e8f0 pressed #1e40af active #1d4ed8} \
    -foreground {disabled #64748b !disabled #ffffff} \
    -bordercolor {focus #0f172a !focus #2563eb} \
    -lightcolor {focus #0f172a !focus #2563eb} -darkcolor {focus #0f172a !focus #2563eb}
. configure -background #f4f6fa

ttk::label .heading -text "Counter" -style Heading.TLabel
ttk::label .subtitle -text "A little focus. One step at a time." -style Subtitle.TLabel
ttk::frame .card -style Card.TFrame -padding {24 20}
ttk::label .card.caption -text "CURRENT COUNT" -style Caption.TLabel
ttk::label .card.count -textvariable count -anchor center -style Count.TLabel
ttk::label .card.range -text "0 - 999" -style Caption.TLabel
ttk::frame .controls
ttk::button .controls.increment -text "Increment +1" -underline 0 \
    -style Primary.TButton -command {dispatch increment}
ttk::button .controls.reset -text "Reset" -underline 0 -command {dispatch reset}
ttk::label .status -textvariable status -anchor center -justify center \
    -wraplength [expr {[font measure CounterBody "0"] * 40}] -style Status.TLabel
grid .heading -row 0 -column 0 -sticky w -padx 28 -pady {24 4}
grid .subtitle -row 1 -column 0 -sticky w -padx 28 -pady {0 20}
grid .card -row 2 -column 0 -sticky ew -padx 28 -pady {0 20}
pack .card.caption .card.count .card.range -pady 3
grid .controls -row 3 -column 0 -sticky ew -padx 28
grid .controls.increment -row 0 -column 0 -sticky ew -padx {0 12}
grid .controls.reset -row 0 -column 1 -sticky ew
grid columnconfigure .controls 0 -weight 1 -minsize [font measure CounterBody "000000000000000000000"]
grid .status -row 4 -column 0 -sticky ew -padx 28 -pady {16 24}
grid columnconfigure . 0 -weight 1
bind . <Alt-i> {.controls.increment invoke}
bind . <Alt-r> {.controls.reset invoke}
update_controls
after idle {focus .controls.increment}
