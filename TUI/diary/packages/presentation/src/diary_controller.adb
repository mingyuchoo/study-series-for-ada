with Ada.Characters.Conversions;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Calendar_Commands;
with Diary_Editor;
with Diary_Entries;
with Diary_Input;
with Diary_Screen_State;
with Diary_Service;
with Diary_Text;

package body Diary_Controller is
   use Ada.Strings.Wide_Wide_Unbounded;
   use Diary_Screen_State;
   use Diary_Input;
   use Diary_Calendar_Commands;
   use type Diary_Service.Outcome;
   use type Diary_Editor.Text_Buffer;
   use type Diary_Keymaps.Kind;
   package Buffer_Vectors is new
     Ada.Containers.Vectors (Positive, Diary_Editor.Text_Buffer);
   type History is record
      Undo, Redo : Buffer_Vectors.Vector;
   end record;
   type Prefix_Kind is (No_Prefix, Control_X_Prefix, Goto_Prefix);
   Newline       : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (10);
   Ctrl_Space    : constant Wide_Wide_Character := Wide_Wide_Character'Val (0);
   Ctrl_A        : constant Wide_Wide_Character := Wide_Wide_Character'Val (1);
   Ctrl_B        : constant Wide_Wide_Character := Wide_Wide_Character'Val (2);
   Ctrl_D        : constant Wide_Wide_Character := Wide_Wide_Character'Val (4);
   Ctrl_E        : constant Wide_Wide_Character := Wide_Wide_Character'Val (5);
   Ctrl_F        : constant Wide_Wide_Character := Wide_Wide_Character'Val (6);
   Ctrl_G        : constant Wide_Wide_Character := Wide_Wide_Character'Val (7);
   Backspace_Key : constant Wide_Wide_Character := Wide_Wide_Character'Val (8);
   Tab_Key       : constant Wide_Wide_Character := Wide_Wide_Character'Val (9);
   Ctrl_K        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (11);
   Ctrl_N        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (14);
   Ctrl_P        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (16);
   Ctrl_S        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (19);
   Ctrl_W        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (23);
   Ctrl_X        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (24);
   Ctrl_Y        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (25);
   Ctrl_Slash    : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (31);
   Rubout_Key    : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (127);
   procedure Run
     (Store  : in out Diary_Repositories.Repository'Class;
      Screen : in out Diary_Screen.Port'Class;
      Today  : Diary_Dates.Date;
      Keymap : Diary_Keymaps.Kind := Diary_Keymaps.Emacs)
   is
      State     : Diary_Screen_State.State;
      Event     : Input_Event;
      Finished  : Boolean := False;
      Histories : array (Edit_Field) of History;
      Register  : Unbounded_Wide_Wide_String;
      Prefix    : Prefix_Kind := No_Prefix;
      Typing    : Boolean := False;
      procedure Message (Text : Wide_Wide_String) is
      begin
         State.Message := To_Unbounded_Wide_Wide_String (Text);
      end Message;
      procedure Refresh is
         Result : Diary_Repositories.Entry_Result;
      begin
         State.Scroll := 0;
         State.Read_Failed := True;
         State.Exists := False;
         State.Markers := Diary_Service.Month_Days (Store, State.Selected);
         Result := Diary_Service.Read (Store, State.Selected);
         State.Item := Result.Item;
         State.Exists := Result.Found;
         State.Read_Failed := False;
      end Refresh;
      procedure Begin_Edit is
      begin
         if State.Read_Failed then
            Message
              ("Cannot edit unreadable data. Resolve the file error first.");
            return;
         end if;
         State.Was_Existing := State.Exists;
         Diary_Editor.Load
           (State.Title,
            (if State.Exists
             then To_Wide_Wide_String (State.Item.Title)
             else ""));
         Diary_Editor.Load
           (State.Content,
            (if State.Exists
             then To_Wide_Wide_String (State.Item.Content)
             else ""));
         State.Field := Title_Field;
         State.Mode := Editing;
         State.Modal := Normal_Mode;
         State.Anchor := Diary_Editor.Position (State.Title);
         State.Mark_Active := False;
         State.Prompt_Shown := False;
         Prefix := No_Prefix;
         Typing := False;
         for Item of Histories loop
            Item.Undo.Clear;
            Item.Redo.Clear;
         end loop;
         Message
           ((if State.Keymap = Diary_Keymaps.Helix
             then
               "Normal mode: i inserts, :w saves, :q closes. Title is required."
             else "Ctrl+S saves; Esc cancels. Title is required."));
      end Begin_Edit;
      procedure Save (Stay : Boolean := False) is
         Item   : constant Diary_Entries.Entry_Data :=
           (State.Selected,
            To_Unbounded_Wide_Wide_String (Diary_Editor.Text (State.Title)),
            To_Unbounded_Wide_Wide_String (Diary_Editor.Text (State.Content)));
         Result : constant Diary_Service.Outcome :=
           (if State.Was_Existing
            then Diary_Service.Update (Store, Item)
            else Diary_Service.Create (Store, Item));
      begin
         case Result is
            when Diary_Service.Success        =>
               Refresh;
               if Stay then
                  State.Was_Existing := True;
               else
                  State.Mode := Reading;
               end if;
               Message ("Entry saved");

            when Diary_Service.Invalid_Entry  =>
               Message
                 ("Enter a nonblank title; control characters are not allowed.");

            when Diary_Service.Already_Exists =>
               Message ("An entry already exists for this date.");

            when Diary_Service.Not_Found      =>
               Message
                 ("The original entry is missing. Your draft is retained.");
         end case;
      end Save;
      function Dirty return Boolean is
         Original_Title : constant Wide_Wide_String :=
           (if State.Was_Existing
            then To_Wide_Wide_String (State.Item.Title)
            else "");
         Original_Body  : constant Wide_Wide_String :=
           (if State.Was_Existing
            then To_Wide_Wide_String (State.Item.Content)
            else "");
      begin
         return
           Diary_Editor.Text (State.Title) /= Original_Title
           or else Diary_Editor.Text (State.Content) /= Original_Body;
      end Dirty;
      procedure Close_Editor is
      begin
         State.Mode := (if Dirty then Confirm_Discard else Reading);
      end Close_Editor;
      function Size (Buffer : Diary_Editor.Text_Buffer) return Natural
      is (Diary_Editor.Text (Buffer)'Length);
      procedure Switch_Field (Target : Edit_Field) is
      begin
         State.Field := Target;
         State.Anchor :=
           Diary_Editor.Position
             ((if Target = Title_Field then State.Title else State.Content));
         State.Mark_Active := False;
         if State.Modal = Select_Mode then
            State.Modal := Normal_Mode;
         end if;
         Prefix := No_Prefix;
         Typing := False;
      end Switch_Field;
      procedure Checkpoint (Buffer : Diary_Editor.Text_Buffer) is
         Item : History renames Histories (State.Field);
      begin
         if Item.Undo.Is_Empty or else Item.Undo.Last_Element /= Buffer then
            Item.Undo.Append (Buffer);
         end if;
         Item.Redo.Clear;
      end Checkpoint;
      procedure Restore
        (Buffer   : in out Diary_Editor.Text_Buffer;
         From, To : in out Buffer_Vectors.Vector;
         Empty    : Wide_Wide_String)
      is
         Current : constant Wide_Wide_String := Diary_Editor.Text (Buffer);
      begin
         while not From.Is_Empty
           and then Diary_Editor.Text (From.Last_Element) = Current
         loop
            From.Delete_Last;
         end loop;
         if From.Is_Empty then
            Message (Empty);
            return;
         end if;
         To.Append (Buffer);
         Buffer := From.Last_Element;
         From.Delete_Last;
         State.Anchor := Diary_Editor.Position (Buffer);
         State.Mark_Active := False;
      end Restore;
      procedure Undo (Buffer : in out Diary_Editor.Text_Buffer) is
         Item : History renames Histories (State.Field);
      begin
         Restore (Buffer, Item.Undo, Item.Redo, "Nothing to undo");
      end Undo;
      procedure Redo (Buffer : in out Diary_Editor.Text_Buffer) is
         Item : History renames Histories (State.Field);
      begin
         Restore (Buffer, Item.Redo, Item.Undo, "Nothing to redo");
      end Redo;
      procedure Take
        (Buffer   : in out Diary_Editor.Text_Buffer;
         From, To : Natural;
         Remove   : Boolean)
      is
         Value : constant Wide_Wide_String := Diary_Editor.Text (Buffer);
      begin
         Register := To_Unbounded_Wide_Wide_String (Value (From + 1 .. To));
         if Remove then
            Diary_Editor.Remove (Buffer, From, To);
         end if;
      end Take;
      function Pasted (Is_Title : Boolean) return Wide_Wide_String is
         Result : Unbounded_Wide_Wide_String;
      begin
         if not Is_Title then
            return To_Wide_Wide_String (Register);
         end if;
         for Letter of To_Wide_Wide_String (Register) loop
            if Letter /= Newline then
               Append (Result, Letter);
            end if;
         end loop;
         return To_Wide_Wide_String (Result);
      end Pasted;
      procedure Insert_Key
        (Buffer : in out Diary_Editor.Text_Buffer; Is_Title : Boolean) is
      begin
         case Wide_Wide_Character'Pos (Event.Letter) is
            when 8 | 127                       =>
               Diary_Editor.Backspace (Buffer);

            when 10 | 13                       =>
               if Is_Title then
                  Switch_Field (Body_Field);
               else
                  Diary_Editor.Insert (Buffer, Newline);
               end if;

            when 32 .. 126 | 160 .. 16#10FFFF# =>
               Diary_Editor.Insert (Buffer, Event.Letter);

            when others                        =>
               null;
         end case;
      end Insert_Key;
      procedure Emacs_Edit
        (Buffer : in out Diary_Editor.Text_Buffer; Is_Title : Boolean)
      is
         use Diary_Editor;
         Was_Typing : constant Boolean := Typing;
         Point      : constant Natural := Position (Buffer);
         procedure Kill (From, To : Natural) is
         begin
            if To > From then
               Checkpoint (Buffer);
               Take (Buffer, From, To, Remove => True);
            end if;
            State.Mark_Active := False;
         end Kill;
         procedure Region (Remove : Boolean) is
            From : constant Natural := Natural'Min (State.Anchor, Point);
            To   : constant Natural := Natural'Max (State.Anchor, Point);
         begin
            if not State.Mark_Active then
               Message ("No region. Set the mark with C-Space first.");
            elsif Remove then
               Kill (From, To);
            else
               Take (Buffer, From, To, Remove => False);
               State.Mark_Active := False;
               Message ("Region copied");
            end if;
         end Region;
         procedure Yank is
            Value : constant Wide_Wide_String := Pasted (Is_Title);
         begin
            if Value'Length > 0 then
               Checkpoint (Buffer);
               Insert (Buffer, Value);
               State.Mark_Active := False;
            end if;
         end Yank;
      begin
         Typing := False;
         if Prefix = Control_X_Prefix then
            Prefix := No_Prefix;
            if Event.Kind = Character_Key then
               case Event.Letter is
                  when Ctrl_S    =>
                     Save (Stay => True);

                  when 'u' | 'U' =>
                     Undo (Buffer);

                  when 'k' | 'K' =>
                     Close_Editor;

                  when others    =>
                     Message ("C-x: C-s save, u undo, k close");
               end case;
            end if;
            return;
         end if;
         case Event.Kind is
            when Left_Key      =>
               Move (Buffer, Backward);

            when Right_Key     =>
               Move (Buffer, Forward);

            when Up_Key        =>
               Move (Buffer, Upward);

            when Down_Key      =>
               Move (Buffer, Downward);

            when Meta_Key      =>
               case Event.Letter is
                  when 'f' | 'F'                  =>
                     Move (Buffer, Word_Forward);

                  when 'b' | 'B'                  =>
                     Move (Buffer, Word_Backward);

                  when '<'                        =>
                     Move (Buffer, Buffer_Start);

                  when '>'                        =>
                     Move (Buffer, Buffer_End);

                  when 'd' | 'D'                  =>
                     Move (Buffer, Word_Forward);
                     Kill (Point, Position (Buffer));

                  when Backspace_Key | Rubout_Key =>
                     Move (Buffer, Word_Backward);
                     Kill (Position (Buffer), Point);

                  when 'w' | 'W'                  =>
                     Region (Remove => False);

                  when others                     =>
                     null;
               end case;

            when Character_Key =>
               case Event.Letter is
                  when Ctrl_Space =>
                     State.Anchor := Point;
                     State.Mark_Active := True;
                     Message ("Mark set");

                  when Ctrl_A     =>
                     Move (Buffer, Line_Start);

                  when Ctrl_B     =>
                     Move (Buffer, Backward);

                  when Ctrl_D     =>
                     Kill (Point, Natural'Min (Size (Buffer), Point + 1));
                     Register := Null_Unbounded_Wide_Wide_String;

                  when Ctrl_E     =>
                     Move (Buffer, Line_End);

                  when Ctrl_F     =>
                     Move (Buffer, Forward);

                  when Ctrl_G     =>
                     State.Mark_Active := False;
                     Message ("Quit");

                  when Ctrl_K     =>
                     Move (Buffer, Line_End);
                     Kill
                       (Point,
                        (if Position (Buffer) = Point
                         then Natural'Min (Size (Buffer), Point + 1)
                         else Position (Buffer)));

                  when Ctrl_N     =>
                     Move (Buffer, Downward);

                  when Ctrl_P     =>
                     Move (Buffer, Upward);

                  when Ctrl_W     =>
                     Region (Remove => True);

                  when Ctrl_X     =>
                     Prefix := Control_X_Prefix;

                  when Ctrl_Y     =>
                     Yank;

                  when Ctrl_Slash =>
                     Undo (Buffer);

                  when others     =>
                     if not Was_Typing then
                        Checkpoint (Buffer);
                     end if;
                     Typing := True;
                     State.Mark_Active := False;
                     Insert_Key (Buffer, Is_Title);
               end case;

            when others        =>
               null;
         end case;
      end Emacs_Edit;
      procedure Show_Prompt is
      begin
         State.Prompt := Null_Unbounded_Wide_Wide_String;
         State.Prompt_Shown := True;
         Prefix := No_Prefix;
         Message ("");
      end Show_Prompt;
      procedure Helix_Edit
        (Buffer : in out Diary_Editor.Text_Buffer; Is_Title : Boolean)
      is
         use Diary_Editor;
         Point : constant Natural := Position (Buffer);
         From  : constant Natural := Natural'Min (State.Anchor, Point);
         Last  : constant Natural := Natural'Max (State.Anchor, Point);
         To    : constant Natural := Natural'Min (Size (Buffer), Last + 1);
         procedure Step (Direction : Movement) is
         begin
            Move (Buffer, Direction);
            if State.Modal /= Select_Mode then
               State.Anchor := Position (Buffer);
            end if;
         end Step;
         procedure Word (Motion : Word_Motion) is
            Anchor, Head : Natural;
         begin
            Word_Range (Buffer, Motion, Anchor, Head);
            if State.Modal /= Select_Mode then
               State.Anchor := Anchor;
            end if;
            Set_Position (Buffer, Head);
         end Word;
         procedure Start_Insert (Target : Natural) is
         begin
            Checkpoint (Buffer);
            Set_Position (Buffer, Target);
            State.Anchor := Position (Buffer);
            State.Modal := Insert_Mode;
         end Start_Insert;
         function Line_Edge (Offset : Natural; Edge : Movement) return Natural
         is
            Probe : Text_Buffer := Buffer;
         begin
            Set_Position (Probe, Offset);
            Move (Probe, Edge);
            return Position (Probe);
         end Line_Edge;
         procedure Select_Line is
            First : constant Natural := Line_Edge (From, Line_Start);
            Final : Natural := Line_Edge (Last, Line_End);
         begin
            if From = First
              and then Last = Final
              and then Final < Size (Buffer)
            then
               Final := Line_Edge (Final + 1, Line_End);
            end if;
            State.Anchor := First;
            Set_Position (Buffer, Final);
         end Select_Line;
         procedure Open_Line (Below : Boolean) is
         begin
            if Is_Title then
               Start_Insert
                 (Line_Edge
                    ((if Below then Last else From),
                     (if Below then Line_End else Line_Start)));
            elsif Below then
               Start_Insert (Line_Edge (Last, Line_End));
               Insert (Buffer, Newline);
            else
               Start_Insert (Line_Edge (From, Line_Start));
               Insert (Buffer, Newline);
               Move (Buffer, Backward);
            end if;
            State.Anchor := Position (Buffer);
         end Open_Line;
         procedure Paste (After : Boolean) is
            Value    : constant Wide_Wide_String := Pasted (Is_Title);
            Linewise : constant Boolean :=
              Value'Length > 0 and then Value (Value'Last) = Newline;
            Target   : Natural;
         begin
            if Value'Length = 0 then
               Message ("Nothing to paste");
               return;
            end if;
            Checkpoint (Buffer);
            if not Linewise then
               Target := (if After then To else From);
            elsif not After then
               Target := Line_Edge (From, Line_Start);
            else
               Target := Line_Edge (Last, Line_End);
               if Target = Size (Buffer) then
                  Set_Position (Buffer, Target);
                  Insert (Buffer, Newline);
               end if;
               Target := Target + 1;
            end if;
            Set_Position (Buffer, Target);
            Insert (Buffer, Value);
            State.Anchor := Target;
            Set_Position (Buffer, Target + Value'Length - 1);
            State.Modal := Normal_Mode;
         end Paste;
      begin
         if State.Modal = Insert_Mode then
            case Event.Kind is
               when Escape_Key    =>
                  State.Modal := Normal_Mode;

               when Left_Key      =>
                  Move (Buffer, Backward);

               when Right_Key     =>
                  Move (Buffer, Forward);

               when Up_Key        =>
                  Move (Buffer, Upward);

               when Down_Key      =>
                  Move (Buffer, Downward);

               when Character_Key =>
                  case Event.Letter is
                     when Ctrl_A =>
                        Move (Buffer, Line_Start);

                     when Ctrl_E =>
                        Move (Buffer, Line_End);

                     when others =>
                        Insert_Key (Buffer, Is_Title);
                  end case;

               when others        =>
                  null;
            end case;
            if State.Field = (if Is_Title then Title_Field else Body_Field)
            then
               State.Anchor := Position (Buffer);
            end if;
            return;
         end if;
         case Event.Kind is
            when Escape_Key    =>
               State.Modal := Normal_Mode;
               Prefix := No_Prefix;

            when Left_Key      =>
               Step (Backward);

            when Right_Key     =>
               Step (Forward);

            when Up_Key        =>
               Step (Upward);

            when Down_Key      =>
               Step (Downward);

            when Character_Key =>
               if Prefix = Goto_Prefix then
                  Prefix := No_Prefix;
                  case Event.Letter is
                     when 'g'    =>
                        Step (Buffer_Start);

                     when 'e'    =>
                        Step (Buffer_End);

                     when 'h'    =>
                        Step (Line_Start);

                     when 'l'    =>
                        Step (Line_End);

                     when others =>
                        null;
                  end case;
                  return;
               end if;
               case Event.Letter is
                  when 'h'    =>
                     Step (Backward);

                  when 'l'    =>
                     Step (Forward);

                  when 'j'    =>
                     Step (Downward);

                  when 'k'    =>
                     Step (Upward);

                  when Ctrl_A =>
                     Step (Line_Start);

                  when Ctrl_E =>
                     Step (Line_End);

                  when 'w'    =>
                     Word (Next_Word_Start);

                  when 'e'    =>
                     Word (Next_Word_End);

                  when 'b'    =>
                     Word (Previous_Word_Start);

                  when 'g'    =>
                     Prefix := Goto_Prefix;

                  when 'x'    =>
                     Select_Line;

                  when '%'    =>
                     State.Anchor := 0;
                     Set_Position (Buffer, Size (Buffer));

                  when ';'    =>
                     State.Anchor := Point;

                  when 'v'    =>
                     State.Modal :=
                       (if State.Modal = Select_Mode
                        then Normal_Mode
                        else Select_Mode);

                  when 'i'    =>
                     Start_Insert (From);

                  when 'a'    =>
                     Start_Insert (To);

                  when 'I'    =>
                     Start_Insert (Line_Edge (From, Line_Start));

                  when 'A'    =>
                     Start_Insert (Line_Edge (Last, Line_End));

                  when 'o'    =>
                     Open_Line (Below => True);

                  when 'O'    =>
                     Open_Line (Below => False);

                  when 'd'    =>
                     if To > From then
                        Checkpoint (Buffer);
                        Take (Buffer, From, To, Remove => True);
                     end if;
                     State.Anchor := Position (Buffer);
                     State.Modal := Normal_Mode;

                  when 'c'    =>
                     Checkpoint (Buffer);
                     if To > From then
                        Take (Buffer, From, To, Remove => True);
                     end if;
                     State.Anchor := Position (Buffer);
                     State.Modal := Insert_Mode;

                  when 'y'    =>
                     Take (Buffer, From, To, Remove => False);
                     State.Modal := Normal_Mode;
                     Message ("Selection yanked");

                  when 'p'    =>
                     Paste (After => True);

                  when 'P'    =>
                     Paste (After => False);

                  when 'u'    =>
                     Undo (Buffer);
                     State.Modal := Normal_Mode;

                  when 'U'    =>
                     Redo (Buffer);
                     State.Modal := Normal_Mode;

                  when ':'    =>
                     Show_Prompt;

                  when others =>
                     null;
               end case;

            when others        =>
               null;
         end case;
      end Helix_Edit;
      procedure Handle_Editor is
      begin
         if Event.Kind = Character_Key and then Event.Letter = Tab_Key then
            Switch_Field
              ((if State.Field = Title_Field
                then Body_Field
                else Title_Field));
         elsif State.Keymap = Diary_Keymaps.Helix then
            if State.Field = Title_Field then
               Helix_Edit (State.Title, True);
            else
               Helix_Edit (State.Content, False);
            end if;
         elsif Event.Kind = Escape_Key then
            Prefix := No_Prefix;
            Close_Editor;
         elsif Prefix = No_Prefix
           and then Event.Kind = Character_Key
           and then Event.Letter = Ctrl_S
         then
            Save;
         elsif State.Field = Title_Field then
            Emacs_Edit (State.Title, True);
         else
            Emacs_Edit (State.Content, False);
         end if;
      end Handle_Editor;
      procedure Run_Command (Command : Wide_Wide_String) is
      begin
         if Command = "" then
            null;
         elsif State.Mode = Reading then
            if Command in "q" | "quit" | "q!" | "quit!" then
               Finished := True;
            else
               Message ("Unknown command: " & Command);
            end if;
         elsif Command in "w" | "write" then
            Save (Stay => True);
         elsif Command in "wq" | "wq!" | "x" | "x!" | "write-quit" then
            Save;
         elsif Command in "q" | "quit" then
            if Dirty then
               Message ("Unsaved changes. Use :w to save or :q! to discard.");
            else
               State.Mode := Reading;
            end if;
         elsif Command in "q!" | "quit!" then
            if Dirty then
               Message ("Changes discarded");
            end if;
            State.Mode := Reading;
         else
            Message ("Unknown command: " & Command);
         end if;
      end Run_Command;
      procedure Handle_Prompt is
         Command : constant Wide_Wide_String :=
           To_Wide_Wide_String (State.Prompt);
      begin
         if Event.Kind = Escape_Key then
            State.Prompt_Shown := False;
         elsif Event.Kind = Character_Key then
            case Wide_Wide_Character'Pos (Event.Letter) is
               when 8 | 127   =>
                  if Command'Length = 0 then
                     State.Prompt_Shown := False;
                  else
                     State.Prompt :=
                       To_Unbounded_Wide_Wide_String
                         (Command (Command'First .. Command'Last - 1));
                  end if;

               when 10 | 13   =>
                  State.Prompt_Shown := False;
                  Run_Command (Command);

               when 32 .. 126 =>
                  Append (State.Prompt, Event.Letter);

               when others    =>
                  null;
            end case;
         end if;
      end Handle_Prompt;
      procedure Navigate (Day_Delta : Integer := 0; Month_Delta : Integer := 0)
      is
      begin
         State.Selected :=
           Diary_Dates.Shift_Month
             (Diary_Dates.Shift_Days (State.Selected, Day_Delta), Month_Delta);
         Refresh;
         Message ("");
      end Navigate;
      procedure Handle_Reading is
      begin
         case Resolve (Event, State.Keymap) is
            when No_Command    =>
               null;

            when Day_Back      =>
               Navigate (Day_Delta => -1);

            when Day_Forward   =>
               Navigate (Day_Delta => 1);

            when Week_Back     =>
               Navigate (Day_Delta => -7);

            when Week_Forward  =>
               Navigate (Day_Delta => 7);

            when Month_Back    =>
               Navigate (Month_Delta => -1);

            when Month_Forward =>
               Navigate (Month_Delta => 1);

            when Go_Today      =>
               State.Selected := Today;
               Refresh;
               Message ("");

            when New_Entry     =>
               if State.Exists then
                  Message ("This date already has an entry. Press E to edit.");
               else
                  Begin_Edit;
               end if;

            when Edit_Entry    =>
               Begin_Edit;

            when Delete_Entry  =>
               if State.Exists or else State.Read_Failed then
                  State.Mode := Confirm_Delete;
               else
                  Message ("There is no entry to delete.");
               end if;

            when Scroll_Down   =>
               if State.Exists
                 and then State.Scroll
                          < Diary_Text.Position_At
                              (To_Wide_Wide_String (State.Item.Content),
                               Length (State.Item.Content),
                               Positive'Max (1, Screen.Preview_Width - 2))
                              .Row
               then
                  State.Scroll := State.Scroll + 1;
               end if;

            when Scroll_Up     =>
               State.Scroll := Natural'Max (1, State.Scroll) - 1;

            when Switch_Keymap =>
               State.Keymap :=
                 (if State.Keymap = Diary_Keymaps.Emacs
                  then Diary_Keymaps.Helix
                  else Diary_Keymaps.Emacs);
               Message ("Keymap: " & Diary_Keymaps.Label (State.Keymap));

            when Open_Prompt   =>
               Show_Prompt;

            when Quit          =>
               Finished := True;
         end case;
      end Handle_Reading;
      procedure Handle_Confirmation is
         Result : Diary_Service.Outcome;
      begin
         if Event.Kind = Escape_Key
           or else (Event.Kind = Character_Key
                    and then Event.Letter in 'n' | 'N')
         then
            State.Mode :=
              (if State.Mode = Confirm_Discard then Editing else Reading);
         elsif Event.Kind = Character_Key and then Event.Letter in 'y' | 'Y'
         then
            if State.Mode = Confirm_Delete then
               Result := Diary_Service.Delete (Store, State.Selected);
               State.Mode := Reading;
               Refresh;
               Message
                 ((if Result = Diary_Service.Success
                   then "Entry deleted"
                   else "Entry no longer exists"));
            else
               State.Mode := Reading;
               Message ("Changes discarded");
            end if;
         end if;
      end Handle_Confirmation;
      procedure Dispatch is
      begin
         if not Screen.Is_Usable then
            if State.Mode = Reading
              and then not State.Prompt_Shown
              and then Event.Kind = Character_Key
              and then Event.Letter in 'q' | 'Q'
            then
               Finished := True;
            end if;
         elsif State.Prompt_Shown then
            Handle_Prompt;
         else
            case State.Mode is
               when Reading                          =>
                  Handle_Reading;

               when Editing                          =>
                  Handle_Editor;

               when Confirm_Delete | Confirm_Discard =>
                  Handle_Confirmation;
            end case;
         end if;
      end Dispatch;
      procedure Sync_Selection is
         Point : Natural;
      begin
         State.Select_From := 0;
         State.Select_To := 0;
         if State.Mode not in Editing | Confirm_Discard then
            return;
         end if;
         Point :=
           Diary_Editor.Position
             ((if State.Field = Title_Field
               then State.Title
               else State.Content));
         if State.Keymap = Diary_Keymaps.Helix then
            if State.Modal /= Insert_Mode then
               State.Select_From := Natural'Min (State.Anchor, Point);
               State.Select_To := Natural'Max (State.Anchor, Point) + 1;
            end if;
         elsif State.Mark_Active then
            State.Select_From := Natural'Min (State.Anchor, Point);
            State.Select_To := Natural'Max (State.Anchor, Point);
         end if;
      end Sync_Selection;
   begin
      State.Selected := Today;
      State.Today := Today;
      State.Keymap := Keymap;
      begin
         Refresh;
      exception
         when Error : Diary_Repositories.Storage_Error =>
            Message
              (Ada.Characters.Conversions.To_Wide_Wide_String
                 (Ada.Exceptions.Exception_Message (Error)));
      end;
      Screen.Start;
      loop
         Sync_Selection;
         Screen.Display (State);
         Screen.Next (Event);
         begin
            if State.Keymap = Diary_Keymaps.Helix
              and then Event.Kind = Meta_Key
            then
               declare
                  Letter : constant Wide_Wide_Character := Event.Letter;
               begin
                  Event := (Escape_Key, ' ');
                  Dispatch;
                  Event := (Character_Key, Letter);
                  Dispatch;
               end;
            else
               Dispatch;
            end if;
         exception
            when Error : Diary_Repositories.Storage_Error =>
               Message
                 (Ada.Characters.Conversions.To_Wide_Wide_String
                    (Ada.Exceptions.Exception_Message (Error)));
         end;
         exit when Finished;
      end loop;
   end Run;
end Diary_Controller;
