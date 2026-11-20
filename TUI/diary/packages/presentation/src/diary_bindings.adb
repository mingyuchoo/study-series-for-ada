with Ada.Characters.Handling;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Unbounded;

package body Diary_Bindings is
   use Diary_Input;
   use type Diary_Keymaps.Kind;
   function Wide (Value : String) return Wide_Wide_String
   renames Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode;
   function UTF8 (Value : Wide_Wide_String) return String
   is (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Value));
   function Parse (Value : String) return Key_Sequence is
      Text   : constant Wide_Wide_String := Wide (Value);
      Result : Key_Sequence;
      First  : Positive := Text'First;
      Last   : Natural;
      function Key (Token : Wide_Wide_String) return Input_Event is
         Ch : Wide_Wide_Character;
      begin
         if Token = "Left" then
            return (Left_Key, ' ');
         elsif Token = "Right" then
            return (Right_Key, ' ');
         elsif Token = "Up" then
            return (Up_Key, ' ');
         elsif Token = "Down" then
            return (Down_Key, ' ');
         elsif Token = "Esc" then
            return (Escape_Key, ' ');
         elsif Token = "Tab" then
            return (Character_Key, Wide_Wide_Character'Val (9));
         elsif Token = "Enter" then
            return (Character_Key, Wide_Wide_Character'Val (13));
         elsif Token = "Backspace" then
            return (Character_Key, Wide_Wide_Character'Val (127));
         elsif Token = "Space" then
            return (Character_Key, ' ');
         elsif Token = "C-Space" then
            return (Character_Key, Wide_Wide_Character'Val (0));
         elsif Token = "C-/" then
            return (Character_Key, Wide_Wide_Character'Val (31));
         elsif Token = "M-Backspace" then
            return (Meta_Key, Wide_Wide_Character'Val (127));
         elsif Token'Length = 3
           and then Token (Token'First .. Token'First + 1) = "C-"
         then
            Ch := Token (Token'Last);
            if Ch not in 'a' .. 'z' | 'A' .. 'Z' then
               raise Invalid_Binding with "Use C-a..C-z, C-Space or C-/";
            end if;
            Ch :=
              Wide_Wide_Character'Val (Wide_Wide_Character'Pos (Ch) mod 32);
            if Wide_Wide_Character'Pos (Ch) in 3 | 26 then
               raise Invalid_Binding with "C-c and C-z are terminal signals";
            end if;
            if Wide_Wide_Character'Pos (Ch) = 8 then
               Ch := Wide_Wide_Character'Val (127);
            elsif Wide_Wide_Character'Pos (Ch) = 10 then
               Ch := Wide_Wide_Character'Val (13);
            end if;
            return (Character_Key, Ch);
         elsif Token'Length = 3
           and then Token (Token'First .. Token'First + 1) = "M-"
           and then Wide_Wide_Character'Pos (Token (Token'Last)) in 32 .. 126
         then
            if Token (Token'Last) in '[' | 'O' then
               raise Invalid_Binding
                 with "M-[ and M-O are reserved by terminal escape sequences";
            end if;
            return (Meta_Key, Token (Token'Last));
         elsif Token'Length = 1
           and then Wide_Wide_Character'Pos (Token (Token'First)) >= 32
         then
            return (Character_Key, Token (Token'First));
         end if;
         raise Invalid_Binding with "Unknown key: " & UTF8 (Token);
      end Key;
   begin
      while First <= Text'Last loop
         if Text (First) in ' ' | Wide_Wide_Character'Val (9) then
            First := First + 1;
         else
            Last := First;
            while Last < Text'Last
              and then Text (Last + 1) not in ' ' | Wide_Wide_Character'Val (9)
            loop
               Last := Last + 1;
            end loop;
            if Result.Length = Max_Keys then
               raise Invalid_Binding with "Use at most four keys";
            end if;
            Result.Length := Result.Length + 1;
            Result.Keys (Result.Length) := Key (Text (First .. Last));
            First := Last + 1;
         end if;
      end loop;
      return Result;
   end Parse;

   function Image (Value : Key_Sequence) return String is
      use Ada.Strings.Wide_Wide_Unbounded;
      Result : Unbounded_Wide_Wide_String;
      function Key_Image (Key : Input_Event) return Wide_Wide_String is
         Code : constant Natural := Wide_Wide_Character'Pos (Key.Letter);
      begin
         case Key.Kind is
            when Left_Key      =>
               return "Left";

            when Right_Key     =>
               return "Right";

            when Up_Key        =>
               return "Up";

            when Down_Key      =>
               return "Down";

            when Escape_Key    =>
               return "Esc";

            when Meta_Key      =>
               return
                 "M-"
                 & (if Code = 127 then "Backspace" else [1 => Key.Letter]);

            when Character_Key =>
               case Code is
                  when 0                            =>
                     return "C-Space";

                  when 9                            =>
                     return "Tab";

                  when 13                           =>
                     return "Enter";

                  when 31                           =>
                     return "C-/";

                  when 32                           =>
                     return "Space";

                  when 127                          =>
                     return "Backspace";

                  when 1 .. 8 | 10 .. 12 | 14 .. 30 =>
                     return "C-" & Wide_Wide_Character'Val (Code + 96);

                  when others                       =>
                     return [1 => Key.Letter];
               end case;

            when others        =>
               raise Invalid_Binding with "Unsupported event";
         end case;
      end Key_Image;
   begin
      for Index in 1 .. Value.Length loop
         if Index > 1 then
            Append (Result, ' ');
         end if;
         Append (Result, Key_Image (Value.Keys (Index)));
      end loop;
      return UTF8 (To_Wide_Wide_String (Result));
   end Image;
   function Name (Action : Action_Id) return String
   is (Ada.Characters.Handling.To_Lower (Action_Id'Image (Action)));
   function Action_Named (Value : String) return Action_Id is
   begin
      for Action in Action_Id loop
         if Name (Action) = Value then
            return Action;
         end if;
      end loop;
      raise Invalid_Binding with "Unknown action: " & Value;
   end Action_Named;

   function Build_Canonical
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id) return Key_Sequence is
   begin
      case Action is
         when Save_Entry              =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs
                  then "C-x C-s"
                  else ": w Enter"));

         when Close_Entry             =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs
                  then "C-x k"
                  else ": q Enter"));

         when Save_And_Close          =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs
                  then "C-x C-s C-x k"
                  else ": w q Enter"));

         when Discard_Entry           =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs then "" else ": q ! Enter"));

         when Switch_Field            =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "Tab" else "Tab"));

         when Move_Left               =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-b" else "h"));

         when Move_Right              =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-f" else "l"));

         when Move_Up                 =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-p" else "k"));

         when Move_Down               =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-n" else "j"));

         when Line_Start              =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-a" else "g h"));

         when Line_End                =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-e" else "g l"));

         when Word_Forward            =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-f" else "w"));

         when Word_Backward           =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-b" else "b"));

         when Word_End                =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "e"));

         when Buffer_Start            =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-<" else "g g"));

         when Buffer_End              =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M->" else "g e"));

         when Delete_Forward          =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-d" else ""));

         when Delete_Backward         =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs
                  then "Backspace"
                  else "Backspace"));

         when New_Line                =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs then "Enter" else "Enter"));

         when Kill_Word_Forward       =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-d" else ""));

         when Kill_Word_Backward      =>
            return
              Parse
                ((if Keymap = Diary_Keymaps.Emacs then "M-Backspace" else ""));

         when Kill_Line               =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-k" else ""));

         when Set_Mark                =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-Space" else ""));

         when Cut_Region              =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-w" else ""));

         when Copy_Region             =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-w" else ""));

         when Yank                    =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-y" else ""));

         when Yank_Previous           =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-y" else ""));

         when Undo                    =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-/" else "u"));

         when Undo_Alternate          =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-x u" else ""));

         when Exchange_Mark           =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-x C-x" else ""));

         when Page_Down               =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-v" else ""));

         when Page_Up                 =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-v" else ""));

         when Search_Forward          =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-s" else "/"));

         when Search_Backward         =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-r" else "?"));

         when Cancel_Command          =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-g" else ""));

         when Select_Line             =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "x"));

         when Select_All              =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "%"));

         when Collapse_Selection      =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else ";"));

         when Select_Mode             =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "v"));

         when Insert_Before           =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "i"));

         when Insert_After            =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "a"));

         when Insert_Line_Start       =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "I"));

         when Insert_Line_End         =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "A"));

         when Open_Below              =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "o"));

         when Open_Above              =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "O"));

         when Delete_Selection        =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "d"));

         when Change_Selection        =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "c"));

         when Copy_Selection          =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "y"));

         when Paste_After             =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "p"));

         when Paste_Before            =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "P"));

         when Redo                    =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "U"));

         when Open_Command            =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else ":"));

         when Find_Forward            =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "f"));

         when Find_Backward           =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "F"));

         when Till_Forward            =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "t"));

         when Till_Backward           =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "T"));

         when Repeat_Find             =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "M-."));

         when Replace_Selection       =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "r"));

         when Flip_Selection          =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "M-;"));

         when Search_Next             =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "n"));

         when Search_Previous         =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "N"));

         when Normal_Mode             =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "" else "Esc"));

         when Insert_Left             =>
            return
              Parse ((if Keymap = Diary_Keymaps.Helix then "Left" else ""));

         when Insert_Right            =>
            return
              Parse ((if Keymap = Diary_Keymaps.Helix then "Right" else ""));

         when Insert_Up               =>
            return Parse ((if Keymap = Diary_Keymaps.Helix then "Up" else ""));

         when Insert_Down             =>
            return
              Parse ((if Keymap = Diary_Keymaps.Helix then "Down" else ""));

         when Insert_Start            =>
            return
              Parse ((if Keymap = Diary_Keymaps.Helix then "C-a" else ""));

         when Insert_End              =>
            return
              Parse ((if Keymap = Diary_Keymaps.Helix then "C-e" else ""));

         when Calendar_New            =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "n" else "n"));

         when Calendar_Edit           =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "e" else "e"));

         when Calendar_Delete         =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "d" else "d"));

         when Calendar_Settings       =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "s" else "s"));

         when Calendar_Quit           =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "q" else "q"));

         when Calendar_Left           =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-b" else "h"));

         when Calendar_Right          =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-f" else "l"));

         when Calendar_Up             =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-p" else "k"));

         when Calendar_Down           =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-n" else "j"));

         when Calendar_Previous_Month =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "[" else "["));

         when Calendar_Next_Month     =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "]" else "]"));

         when Calendar_Today          =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "t" else "t"));

         when Calendar_Scroll_Down    =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "C-v" else "C-d"));

         when Calendar_Scroll_Up      =>
            return
              Parse ((if Keymap = Diary_Keymaps.Emacs then "M-v" else "C-u"));

         when Calendar_Switch_Keymap  =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "m" else "m"));

         when Calendar_Command        =>
            return Parse ((if Keymap = Diary_Keymaps.Emacs then "" else ":"));
      end case;
   end Build_Canonical;
   function Build return Binding_Table is
      Result : Binding_Table;
   begin
      for Keymap in Diary_Keymaps.Kind loop
         for Action in Action_Id loop
            Result (Keymap, Action) := Build_Canonical (Keymap, Action);
         end loop;
      end loop;
      return Result;
   end Build;
   Builtins : constant Binding_Table := Build;
   function Canonical
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id) return Key_Sequence
   is (Builtins (Keymap, Action));
   function Supported
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id) return Boolean
   is (Builtins (Keymap, Action).Length > 0);
   function Defaults return Binding_Table is
      Result : Binding_Table := Builtins;
   begin
      -- Command prompts remain available; optional shortcuts start unbound.
      for Keymap in Diary_Keymaps.Kind loop
         Result (Keymap, Save_And_Close) := (others => <>);
      end loop;
      for Action in Save_Entry .. Discard_Entry loop
         Result (Diary_Keymaps.Helix, Action) := (others => <>);
      end loop;
      return Result;
   end Defaults;
   function Applies
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id; Context : Input_Context)
      return Boolean is
   begin
      if not Supported (Keymap, Action) then
         return False;
      end if;
      if Action >= Calendar_New then
         return Context = Calendar_Context;
      end if;
      if Keymap = Diary_Keymaps.Emacs then
         return Context = Emacs_Context;
      end if;
      if Action = Switch_Field then
         return Context in Helix_Normal_Context | Helix_Insert_Context;
      elsif Action
            in Delete_Backward
             | New_Line
             | Normal_Mode
             | Insert_Left .. Insert_End
      then
         return Context = Helix_Insert_Context;
      end if;
      return Context = Helix_Normal_Context;
   end Applies;
   function Starts_With (Whole, Part : Key_Sequence) return Boolean is
   begin
      if Part.Length = 0 or else Whole.Length < Part.Length then
         return False;
      end if;
      for Index in 1 .. Part.Length loop
         if Whole.Keys (Index) /= Part.Keys (Index) then
            return False;
         end if;
      end loop;
      return True;
   end Starts_With;
   function Validate (Value : Binding_Table) return String is
   begin
      for Keymap in Diary_Keymaps.Kind loop
         for A in Action_Id loop
            if not Supported (Keymap, A) and then Value (Keymap, A).Length > 0
            then
               return "Unsupported action: " & Name (A);
            end if;
            for Context in Input_Context loop
               if Applies (Keymap, A, Context)
                 and then Value (Keymap, A).Length > 0
               then
                  for Index in 2 .. Value (Keymap, A).Length loop
                     if Value (Keymap, A).Keys (Index).Kind = Escape_Key
                       or else (Value (Keymap, A).Keys (Index).Kind
                                = Character_Key
                                and then Wide_Wide_Character'Pos
                                           (Value (Keymap, A).Keys (Index)
                                              .Letter)
                                         = 7)
                     then
                        return "Esc and C-g cancel a pending sequence";
                     end if;
                  end loop;
                  if Context = Helix_Normal_Context
                    and then Value (Keymap, A).Keys (1).Kind = Character_Key
                    and then Value (Keymap, A).Keys (1).Letter in '0' .. '9'
                  then
                     return "Digits are reserved for Helix counts";
                  end if;
                  for B in Action_Id loop
                     if B > A
                       and then Applies (Keymap, B, Context)
                       and then (Starts_With
                                   (Value (Keymap, A), Value (Keymap, B))
                                 or else Starts_With
                                           (Value (Keymap, B),
                                            Value (Keymap, A)))
                     then
                        return "Key conflict: " & Name (A) & " / " & Name (B);
                     end if;
                  end loop;
               end if;
            end loop;
         end loop;
      end loop;
      return "";
   end Validate;
   procedure Resolve_Alias
     (Keymap   : Diary_Keymaps.Kind;
      Context  : Input_Context;
      Sequence : Key_Sequence;
      Found    : out Boolean;
      Action   : out Action_Id)
   is
      Keys     : Key_Sequence := Sequence;
      Original : constant Binding_Table := Defaults;
      Match    : Match_Kind;
      procedure Alias_For (Item : Action_Id) is
      begin
         Keys := Original (Keymap, Item);
      end Alias_For;
   begin
      Found := False;
      Action := Action_Id'First;
      if Sequence.Length = 1 then
         declare
            Key : Input_Event := Sequence.Keys (1);
         begin
            if Key.Kind = Meta_Key
              and then Keymap = Diary_Keymaps.Emacs
              and then Key.Letter in 'A' .. 'Z'
            then
               Key.Letter :=
                 Wide_Wide_Character'Val
                   (Wide_Wide_Character'Pos (Key.Letter) + 32);
            end if;
            if Key.Kind = Character_Key
              and then Context = Calendar_Context
              and then Key.Letter in 'A' .. 'Z'
            then
               Key.Letter :=
                 Wide_Wide_Character'Val
                   (Wide_Wide_Character'Pos (Key.Letter) + 32);
            end if;
            Keys.Keys (1) := Key;
            if Context = Calendar_Context then
               case Key.Kind is
                  when Left_Key      =>
                     Alias_For (Calendar_Left);

                  when Right_Key     =>
                     Alias_For (Calendar_Right);

                  when Up_Key        =>
                     Alias_For (Calendar_Up);

                  when Down_Key      =>
                     Alias_For (Calendar_Down);

                  when Meta_Key      =>
                     if Key.Letter = '{' then
                        Alias_For (Calendar_Previous_Month);
                     elsif Key.Letter = '}' then
                        Alias_For (Calendar_Next_Month);
                     elsif Key.Letter in 'v' | 'V' then
                        Alias_For (Calendar_Scroll_Up);
                     end if;

                  when Character_Key =>
                     if Wide_Wide_Character'Pos (Key.Letter) in 10 | 13
                       or else (Keymap = Diary_Keymaps.Helix
                                and then Key.Letter = 'i')
                     then
                        Alias_For (Calendar_Edit);
                     elsif Keymap = Diary_Keymaps.Emacs then
                        if Key.Letter = '.' then
                           Alias_For (Calendar_Today);
                        elsif Key.Letter = 'j' then
                           Alias_For (Calendar_Scroll_Down);
                        elsif Key.Letter = 'k' then
                           Alias_For (Calendar_Scroll_Up);
                        end if;
                     end if;

                  when others        =>
                     null;
               end case;
            elsif Context in Emacs_Context | Helix_Normal_Context then
               case Key.Kind is
                  when Left_Key      =>
                     Alias_For (Move_Left);

                  when Right_Key     =>
                     Alias_For (Move_Right);

                  when Up_Key        =>
                     Alias_For (Move_Up);

                  when Down_Key      =>
                     Alias_For (Move_Down);

                  when Escape_Key    =>
                     if Context = Emacs_Context then
                        Alias_For (Close_Entry);
                     end if;

                  when Character_Key =>
                     if Context = Helix_Normal_Context then
                        if Wide_Wide_Character'Pos (Key.Letter) = 1 then
                           Alias_For (Line_Start);
                        elsif Wide_Wide_Character'Pos (Key.Letter) = 5 then
                           Alias_For (Line_End);
                        end if;
                     end if;

                  when others        =>
                     null;
               end case;
            end if;
         end;
      elsif Sequence.Length = 2
        and then Context = Emacs_Context
        and then Sequence.Keys (1) = Parse ("C-x").Keys (1)
        and then Sequence.Keys (2).Kind = Character_Key
        and then Sequence.Keys (2).Letter in 'K' | 'U'
      then
         Keys.Keys (2).Letter :=
           Wide_Wide_Character'Val
             (Wide_Wide_Character'Pos (Sequence.Keys (2).Letter) + 32);
      end if;
      if Keys /= Sequence then
         Resolve (Original, Keymap, Context, Keys, Match, Action);
         Found := Match = Action_Match;
      end if;
   end Resolve_Alias;
   procedure Resolve
     (Value    : Binding_Table;
      Keymap   : Diary_Keymaps.Kind;
      Context  : Input_Context;
      Sequence : Key_Sequence;
      Match    : out Match_Kind;
      Action   : out Action_Id)
   is
      Original : constant Binding_Table := Defaults;
   begin
      Match := No_Match;
      Action := Action_Id'First;
      for Item in Action_Id loop
         if Applies (Keymap, Item, Context)
           and then Starts_With (Value (Keymap, Item), Sequence)
         then
            Action := Item;
            Match :=
              (if Value (Keymap, Item).Length = Sequence.Length
               then Action_Match
               else Prefix_Match);
            return;
         end if;
      end loop;
      -- A replaced default must not leak back through the legacy handler.
      for Item in Action_Id loop
         if Applies (Keymap, Item, Context)
           and then Value (Keymap, Item) /= Original (Keymap, Item)
           and then Starts_With (Original (Keymap, Item), Sequence)
         then
            Match := Disabled_Match;
            return;
         end if;
      end loop;
   end Resolve;
end Diary_Bindings;
