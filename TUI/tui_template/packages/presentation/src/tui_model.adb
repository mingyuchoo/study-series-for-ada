package body Tui_Model is
   use Tui_Input;

   function Update (Current : State; Event : Input_Event) return State is
   begin
      if Current = Quit or else Event.Kind /= Character_Key then
         return Current;
      end if;

      case Event.Letter is
         when 'q' | 'Q' =>
            return Quit;

         when ' '       =>
            return (if Current = Idle then Active else Idle);

         when others    =>
            return Current;
      end case;
   end Update;
end Tui_Model;
