# Counter UI refresh

The user approved the proposed minimal desktop style and requested implementation.

Keep GWindows on Windows and Tcl/Tk on Linux/macOS. Keep the workspace packages and pure Ada/SPARK core unchanged. All presentation and widget state changes belong in the existing app adapters. Add no dependencies or source comments.

Use a clear heading, short description, prominent count, generous consistent spacing, a blue primary Increment +1 action, and a smaller secondary Reset action. Preserve native button semantics, keyboard focus and mnemonic navigation. At 999 show a maximum notice and disable Increment; Reset returns to zero and restores Increment and its focus. Keep errors distinct from the maximum notice and disable both buttons on backend failure.

Approaches considered: refresh the existing toolkits (selected: smallest complete change); replace the GUI frameworks (unnecessary dependency and packaging changes); cosmetic colors alone (does not improve state feedback).

Validate the real Tk interface against the Ada executable, including increment, maximum, reset, and backend failure. Build and inspect the Windows UI, run the existing package suites, and report platform verification limits.
