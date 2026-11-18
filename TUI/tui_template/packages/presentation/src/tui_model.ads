with Tui_Input;

package Tui_Model
  with Pure
is
   type State is (Idle, Active, Quit);

   function Update
     (Current : State; Event : Tui_Input.Input_Event) return State;
end Tui_Model;
