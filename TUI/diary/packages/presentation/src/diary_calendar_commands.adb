package body Diary_Calendar_Commands is
   use Diary_Input;
   use type Diary_Keymaps.Kind;
   Newline    : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
   Return_Key : constant Wide_Wide_Character := Wide_Wide_Character'Val (13);
   Ctrl_B     : constant Wide_Wide_Character := Wide_Wide_Character'Val (2);
   Ctrl_D     : constant Wide_Wide_Character := Wide_Wide_Character'Val (4);
   Ctrl_F     : constant Wide_Wide_Character := Wide_Wide_Character'Val (6);
   Ctrl_N     : constant Wide_Wide_Character := Wide_Wide_Character'Val (14);
   Ctrl_P     : constant Wide_Wide_Character := Wide_Wide_Character'Val (16);
   Ctrl_U     : constant Wide_Wide_Character := Wide_Wide_Character'Val (21);
   Ctrl_V     : constant Wide_Wide_Character := Wide_Wide_Character'Val (22);
   function Resolve
     (Event : Diary_Input.Input_Event; Keymap : Diary_Keymaps.Kind)
      return Calendar_Command is
   begin
      case Event.Kind is
         when Left_Key      =>
            return Day_Back;

         when Right_Key     =>
            return Day_Forward;

         when Up_Key        =>
            return Week_Back;

         when Down_Key      =>
            return Week_Forward;

         when Meta_Key      =>
            return
              (case Event.Letter is
                 when 'v' | 'V' => Scroll_Up,
                 when '{'       => Month_Back,
                 when '}'       => Month_Forward,
                 when others    => No_Command);

         when Character_Key =>
            case Event.Letter is
               when 'q' | 'Q'                        =>
                  return Quit;

               when '['                              =>
                  return Month_Back;

               when ']'                              =>
                  return Month_Forward;

               when 't' | 'T'                        =>
                  return Go_Today;

               when 'n' | 'N'                        =>
                  return New_Entry;

               when 'e' | 'E' | Newline | Return_Key =>
                  return Edit_Entry;

               when 'd' | 'D'                        =>
                  return Delete_Entry;

               when 'm' | 'M'                        =>
                  return Switch_Keymap;

               when others                           =>
                  null;
            end case;
            if Keymap = Diary_Keymaps.Helix then
               return
                 (case Event.Letter is
                    when 'h' | 'H' => Day_Back,
                    when 'l' | 'L' => Day_Forward,
                    when 'k' | 'K' => Week_Back,
                    when 'j' | 'J' => Week_Forward,
                    when Ctrl_D    => Scroll_Down,
                    when Ctrl_U    => Scroll_Up,
                    when 'i' | 'I' => Edit_Entry,
                    when ':'       => Open_Prompt,
                    when others    => No_Command);
            end if;
            return
              (case Event.Letter is
                 when Ctrl_B             => Day_Back,
                 when Ctrl_F             => Day_Forward,
                 when Ctrl_P             => Week_Back,
                 when Ctrl_N             => Week_Forward,
                 when Ctrl_V | 'j' | 'J' => Scroll_Down,
                 when 'k' | 'K'          => Scroll_Up,
                 when '.'                => Go_Today,
                 when others             => No_Command);

         when others        =>
            return No_Command;
      end case;
   end Resolve;
end Diary_Calendar_Commands;
