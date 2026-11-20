with Ada.Characters.Conversions;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
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
   package Text_Vectors is new
     Ada.Containers.Vectors (Positive, Unbounded_Wide_Wide_String);
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
   Ctrl_R        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (18);
   Ctrl_S        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (19);
   Ctrl_W        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (23);
   Ctrl_V        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (22);
   Ctrl_X        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (24);
   Ctrl_Y        : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (25);
   Ctrl_Slash    : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (31);
   Rubout_Key    : constant Wide_Wide_Character :=
     Wide_Wide_Character'Val (127);
   procedure Run
     (Store    : in out Diary_Repositories.Repository'Class;
      Screen   : in out Diary_Screen.Port'Class;
      Today    : Diary_Dates.Date;
      Keymap   : Diary_Keymaps.Kind := Diary_Keymaps.Emacs;
      Bindings : Diary_Bindings.Binding_Table := Diary_Bindings.Defaults)
   is
      State                        : Diary_Screen_State.State;
      Event                        : Input_Event;
      Finished                     : Boolean := False;
      Histories                    : array (Edit_Field) of History;
      Register                     : Unbounded_Wide_Wide_String;
      Prefix                       : Prefix_Kind := No_Prefix;
      Typing                       : Boolean := False;
      Kill_Ring                    : Text_Vectors.Vector;
      Last_Kill, Last_Yank         : Boolean := False;
      Yank_From, Yank_To           : Natural := 0;
      Ring_Index                   : Positive := 1;
      Count                        : Natural := 0;
      Pending_Find                 : Wide_Wide_Character := ' ';
      Last_Find, Last_Find_Char    : Wide_Wide_Character := ' ';
      Find_Count                   : Positive := 1;
      Search_Origin, Search_Anchor : Natural := 0;
      Search_Mark                  : Boolean := False;
      Last_Search                  : Unbounded_Wide_Wide_String;
      Binding_Pending              : Diary_Bindings.Key_Sequence;
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
         Count := 0;
         Pending_Find := ' ';
         Last_Kill := False;
         Last_Yank := False;
         for Item of Histories loop
            Item.Undo.Clear;
            Item.Redo.Clear;
         end loop;
         Message
           ((if State.Keymap = Diary_Keymaps.Helix
             then
               "Normal mode. See your keys below; :w saves, :q closes. Title required."
             else
               "Use the keys shown below to save, search or close. Title is required."));
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
         Count := 0;
         Pending_Find := ' ';
         Last_Kill := False;
         Last_Yank := False;
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
      procedure Start_Search (Backwards : Boolean) is
      begin
         State.Prompt_Shown := True;
         State.Prompt_Kind :=
           (if Backwards then Search_Backward else Search_Forward);
         State.Prompt := Null_Unbounded_Wide_Wide_String;
         Search_Origin :=
           Diary_Editor.Position
             ((if State.Field = Title_Field
               then State.Title
               else State.Content));
         Search_Anchor := State.Anchor;
         Search_Mark := State.Mark_Active;
         Prefix := No_Prefix;
         Typing := False;
         Last_Kill := False;
         Last_Yank := False;
         Message ("");
      end Start_Search;
      procedure Search
        (Buffer         : in out Diary_Editor.Text_Buffer;
         Query          : Wide_Wide_String;
         Origin         : Natural;
         Backwards      : Boolean;
         Include_Origin : Boolean := True)
      is
         Value  : constant Wide_Wide_String := Diary_Editor.Text (Buffer);
         Length : constant Natural := Value'Length;
         Offset : Natural;
         Start  : Natural;
      begin
         if Query'Length = 0 then
            return;
         elsif Length > 0 and then Query'Length <= Length then
            if Backwards and then State.Keymap = Diary_Keymaps.Emacs then
               -- Emacs point sits before a backward match: its end must not
               -- extend beyond the original point. Wrap if there is no room.
               Start :=
                 (if Origin >= Query'Length
                  then Natural'Min (Origin - Query'Length, Length - 1)
                  else Length - 1);
            else
               Start :=
                 (if Backwards
                  then Natural'Min (Origin, Length - 1)
                  else Origin mod Length);
            end if;
            if not Include_Origin then
               Start :=
                 (if Backwards
                  then (Start + Length - 1) mod Length
                  else (Start + 1) mod Length);
            end if;
            for Distance in 0 .. Length - 1 loop
               Offset :=
                 (if Backwards
                  then (Start + Length - Distance) mod Length
                  else (Start + Distance) mod Length);
               if Offset + Query'Length <= Length
                 and then Value (Offset + 1 .. Offset + Query'Length) = Query
               then
                  if State.Keymap = Diary_Keymaps.Helix then
                     if State.Modal /= Select_Mode then
                        State.Anchor := Offset;
                     end if;
                     Diary_Editor.Set_Position
                       (Buffer, Offset + Query'Length - 1);
                  else
                     Diary_Editor.Set_Position
                       (Buffer,
                        (if Backwards then Offset else Offset + Query'Length));
                  end if;
                  Message ("");
                  return;
               end if;
            end loop;
         end if;
         Message ("Pattern not found");
      end Search;
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
         Was_Kill   : constant Boolean := Last_Kill;
         Was_Yank   : constant Boolean := Last_Yank;
         Point      : constant Natural := Position (Buffer);
         procedure Remember
           (Value      : Wide_Wide_String;
            Backwards  : Boolean := False;
            Accumulate : Boolean := False) is
         begin
            if Value'Length = 0 then
               return;
            end if;
            if Accumulate and then Was_Kill and then not Kill_Ring.Is_Empty
            then
               Kill_Ring.Replace_Element
                 (1,
                  To_Unbounded_Wide_Wide_String
                    ((if Backwards
                      then
                        Value & To_Wide_Wide_String (Kill_Ring.First_Element)
                      else
                        To_Wide_Wide_String (Kill_Ring.First_Element)
                        & Value)));
            else
               Kill_Ring.Prepend (To_Unbounded_Wide_Wide_String (Value));
               if Natural (Kill_Ring.Length) > 32 then
                  Kill_Ring.Delete_Last;
               end if;
            end if;
            Register := Kill_Ring.First_Element;
         end Remember;
         procedure Kill (From, To : Natural) is
            Value : constant Wide_Wide_String := Text (Buffer);
         begin
            if To > From then
               Checkpoint (Buffer);
               Remember
                 (Value (From + 1 .. To), From < Point, Accumulate => True);
               Diary_Editor.Remove (Buffer, From, To);
               Last_Kill := True;
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
               Remember (To_Wide_Wide_String (Register));
               State.Mark_Active := False;
               Message ("Region copied");
            end if;
         end Region;
         procedure Yank (Rotate : Boolean := False) is
         begin
            if Rotate and then not Was_Yank then
               Message ("M-y must follow C-y or M-y");
               return;
            elsif Kill_Ring.Is_Empty then
               Message ("Kill ring is empty");
               return;
            end if;
            if Rotate then
               Ring_Index := Ring_Index mod Positive (Kill_Ring.Length) + 1;
            else
               Ring_Index := 1;
            end if;
            Register := Kill_Ring.Element (Ring_Index);
            declare
               Value : constant Wide_Wide_String := Pasted (Is_Title);
            begin
               Checkpoint (Buffer);
               if Rotate then
                  Diary_Editor.Remove (Buffer, Yank_From, Yank_To);
               else
                  Yank_From := Position (Buffer);
               end if;
               Insert (Buffer, Value);
               Yank_To := Position (Buffer);
               State.Anchor := Yank_From;
               State.Mark_Active := False;
               Last_Yank := True;
            end;
         end Yank;
      begin
         Typing := False;
         Last_Kill := False;
         Last_Yank := False;
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

                  when Ctrl_X    =>
                     Set_Position (Buffer, State.Anchor);
                     State.Anchor := Point;
                     State.Mark_Active := True;

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

                  when 'y' | 'Y'                  =>
                     Yank (Rotate => True);

                  when 'v' | 'V'                  =>
                     for Page_Line in 1 .. 10 loop
                        Move (Buffer, Upward);
                     end loop;

                  when others                     =>
                     null;
               end case;

            when Character_Key =>
               case Event.Letter is
                  when Ctrl_Space      =>
                     State.Anchor := Point;
                     State.Mark_Active := True;
                     Message ("Mark set");

                  when Ctrl_A          =>
                     Move (Buffer, Line_Start);

                  when Ctrl_B          =>
                     Move (Buffer, Backward);

                  when Ctrl_D          =>
                     if Point < Size (Buffer) then
                        Checkpoint (Buffer);
                        Diary_Editor.Remove (Buffer, Point, Point + 1);
                     end if;
                     State.Mark_Active := False;
                     State.Anchor := Natural'Min (State.Anchor, Size (Buffer));

                  when Ctrl_E          =>
                     Move (Buffer, Line_End);

                  when Ctrl_F          =>
                     Move (Buffer, Forward);

                  when Ctrl_G          =>
                     State.Mark_Active := False;
                     Message ("Quit");

                  when Ctrl_K          =>
                     Move (Buffer, Line_End);
                     Kill
                       (Point,
                        (if Position (Buffer) = Point
                         then Natural'Min (Size (Buffer), Point + 1)
                         else Position (Buffer)));

                  when Ctrl_N          =>
                     Move (Buffer, Downward);

                  when Ctrl_P          =>
                     Move (Buffer, Upward);

                  when Ctrl_S | Ctrl_R =>
                     Start_Search (Event.Letter = Ctrl_R);

                  when Ctrl_V          =>
                     for Page_Line in 1 .. 10 loop
                        Move (Buffer, Downward);
                     end loop;

                  when Ctrl_W          =>
                     Region (Remove => True);

                  when Ctrl_X          =>
                     Prefix := Control_X_Prefix;

                  when Ctrl_Y          =>
                     Yank;

                  when Ctrl_Slash      =>
                     Undo (Buffer);

                  when others          =>
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
         State.Prompt_Kind := Command_Prompt;
         Prefix := No_Prefix;
         Message ("");
      end Show_Prompt;
      procedure Helix_Edit
        (Buffer : in out Diary_Editor.Text_Buffer; Is_Title : Boolean)
      is
         use Diary_Editor;
         Point   : constant Natural := Position (Buffer);
         From    : constant Natural := Natural'Min (State.Anchor, Point);
         Last    : constant Natural := Natural'Max (State.Anchor, Point);
         To      : constant Natural := Natural'Min (Size (Buffer), Last + 1);
         Repeats : constant Positive := Positive'Max (1, Count);
         procedure Step (Direction : Movement) is
         begin
            for Repetition in 1 .. Repeats loop
               Move (Buffer, Direction);
            end loop;
            if State.Modal /= Select_Mode then
               State.Anchor := Position (Buffer);
            end if;
         end Step;
         procedure Word (Motion : Word_Motion) is
            Anchor, Head : Natural;
         begin
            for Repetition in 1 .. Repeats loop
               Word_Range (Buffer, Motion, Anchor, Head);
               if State.Modal /= Select_Mode and then Repetition = 1 then
                  State.Anchor := Anchor;
               end if;
               Set_Position (Buffer, Head);
            end loop;
         end Word;
         procedure Find_Character
           (Motion, Letter : Wide_Wide_Character; Repeat : Boolean := False)
         is
            Value     : constant Wide_Wide_String := Text (Buffer);
            Target    : Natural := Point;
            Backwards : constant Boolean := Motion in 'F' | 'T';
            Found     : Boolean;
         begin
            if Repeat then
               if Motion = 't'
                 and then Target + 1 < Value'Length
                 and then Value (Target + 2) = Letter
               then
                  Target := Target + 1;
               elsif Motion = 'T'
                 and then Target > 0
                 and then Value (Target) = Letter
               then
                  Target := Target - 1;
               end if;
            end if;
            for Repetition in 1 .. Find_Count loop
               Found := False;
               while (if Backwards
                      then Target > 0
                      else Target + 1 < Value'Length)
               loop
                  Target := (if Backwards then Target - 1 else Target + 1);
                  if Value (Target + 1) = Letter then
                     Found := True;
                     exit;
                  end if;
               end loop;
               if not Found then
                  Message ("Character not found");
                  return;
               end if;
            end loop;
            if Motion = 't' then
               Target := Target - 1;
            elsif Motion = 'T' then
               Target := Target + 1;
            end if;
            if State.Modal /= Select_Mode then
               State.Anchor := Point;
            end if;
            Set_Position (Buffer, Target);
            Last_Find := Motion;
            Last_Find_Char := Letter;
         end Find_Character;
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
            Current_From : constant Natural :=
              Natural'Min (State.Anchor, Position (Buffer));
            Current_Last : constant Natural :=
              Natural'Max (State.Anchor, Position (Buffer));
            First        : constant Natural :=
              Line_Edge (Current_From, Line_Start);
            Final        : Natural := Line_Edge (Current_Last, Line_End);
         begin
            if Current_From = First
              and then Current_Last = Final
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
            Repeated : Unbounded_Wide_Wide_String;
         begin
            for Repetition in 1 .. Repeats loop
               Append (Repeated, Pasted (Is_Title));
            end loop;
            declare
               Value    : constant Wide_Wide_String :=
                 To_Wide_Wide_String (Repeated);
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
            end;
         end Paste;
      begin
         if State.Modal = Insert_Mode then
            case Event.Kind is
               when Escape_Key    =>
                  State.Modal := Normal_Mode;
                  Move (Buffer, Backward);

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
         if Event.Kind = Escape_Key then
            Count := 0;
            Pending_Find := ' ';
         elsif Pending_Find /= ' ' then
            if Event.Kind = Character_Key
              and then Wide_Wide_Character'Pos (Event.Letter) >= 32
            then
               if Pending_Find = 'r' then
                  if To > From then
                     declare
                        Value : Wide_Wide_String :=
                          Text (Buffer) (From + 1 .. To);
                     begin
                        for Letter of Value loop
                           if Letter /= Newline then
                              Letter := Event.Letter;
                           end if;
                        end loop;
                        Checkpoint (Buffer);
                        Diary_Editor.Remove (Buffer, From, To);
                        Insert (Buffer, Value);
                        State.Anchor := From;
                        Set_Position (Buffer, To - 1);
                     end;
                  end if;
               else
                  Find_Character (Pending_Find, Event.Letter);
               end if;
            end if;
            Pending_Find := ' ';
            Count := 0;
            return;
         elsif Event.Kind = Character_Key and then Event.Letter in '0' .. '9'
         then
            Count :=
              Natural'Min
                (9999,
                 Count
                 * 10
                 + Wide_Wide_Character'Pos (Event.Letter)
                 - Wide_Wide_Character'Pos ('0'));
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

            when Meta_Key      =>
               if Event.Letter = ';' then
                  Set_Position (Buffer, State.Anchor);
                  State.Anchor := Point;
               elsif Event.Letter = '.' and then Last_Find /= ' ' then
                  Find_Count := Repeats;
                  Find_Character (Last_Find, Last_Find_Char, Repeat => True);
               end if;

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
                  Count := 0;
                  return;
               end if;
               case Event.Letter is
                  when 'h'                         =>
                     Step (Backward);

                  when 'l'                         =>
                     Step (Forward);

                  when 'j'                         =>
                     Step (Downward);

                  when 'k'                         =>
                     Step (Upward);

                  when Ctrl_A                      =>
                     Step (Line_Start);

                  when Ctrl_E                      =>
                     Step (Line_End);

                  when 'w'                         =>
                     Word (Next_Word_Start);

                  when 'e'                         =>
                     Word (Next_Word_End);

                  when 'b'                         =>
                     Word (Previous_Word_Start);

                  when 'g'                         =>
                     Prefix := Goto_Prefix;
                     return;

                  when 'f' | 'F' | 't' | 'T' | 'r' =>
                     Pending_Find := Event.Letter;
                     Find_Count := Repeats;
                     return;

                  when 'x'                         =>
                     for Repetition in 1 .. Repeats loop
                        Select_Line;
                     end loop;

                  when '%'                         =>
                     State.Anchor := 0;
                     Set_Position (Buffer, Size (Buffer));

                  when ';'                         =>
                     State.Anchor := Point;

                  when 'v'                         =>
                     State.Modal :=
                       (if State.Modal = Select_Mode
                        then Normal_Mode
                        else Select_Mode);

                  when 'i'                         =>
                     Start_Insert (From);

                  when 'a'                         =>
                     Start_Insert (To);

                  when 'I'                         =>
                     Start_Insert (Line_Edge (From, Line_Start));

                  when 'A'                         =>
                     Start_Insert (Line_Edge (Last, Line_End));

                  when 'o'                         =>
                     Open_Line (Below => True);

                  when 'O'                         =>
                     Open_Line (Below => False);

                  when 'd'                         =>
                     if To > From then
                        Checkpoint (Buffer);
                        Take (Buffer, From, To, Remove => True);
                     end if;
                     State.Anchor := Position (Buffer);
                     State.Modal := Normal_Mode;

                  when 'c'                         =>
                     Checkpoint (Buffer);
                     if To > From then
                        Take (Buffer, From, To, Remove => True);
                     end if;
                     State.Anchor := Position (Buffer);
                     State.Modal := Insert_Mode;

                  when 'y'                         =>
                     Take (Buffer, From, To, Remove => False);
                     State.Modal := Normal_Mode;
                     Message ("Selection yanked");

                  when 'p'                         =>
                     Paste (After => True);

                  when 'P'                         =>
                     Paste (After => False);

                  when 'u'                         =>
                     Undo (Buffer);
                     State.Modal := Normal_Mode;

                  when 'U'                         =>
                     Redo (Buffer);
                     State.Modal := Normal_Mode;

                  when ':'                         =>
                     Show_Prompt;

                  when '/' | '?'                   =>
                     Start_Search (Event.Letter = '?');

                  when 'n' | 'N'                   =>
                     for Repetition in 1 .. Repeats loop
                        Search
                          (Buffer,
                           To_Wide_Wide_String (Last_Search),
                           (if Event.Letter = 'N'
                            then Natural'Min (State.Anchor, Position (Buffer))
                            else
                              Natural'Max (State.Anchor, Position (Buffer))),
                           Event.Letter = 'N',
                           False);
                     end loop;

                  when others                      =>
                     null;
               end case;

            when others        =>
               null;
         end case;
         Count := 0;
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
         Command   : constant Wide_Wide_String :=
           To_Wide_Wide_String (State.Prompt);
         Searching : constant Boolean := State.Prompt_Kind /= Command_Prompt;
         procedure Restore_Search is
         begin
            if State.Field = Title_Field then
               Diary_Editor.Set_Position (State.Title, Search_Origin);
            else
               Diary_Editor.Set_Position (State.Content, Search_Origin);
            end if;
            State.Anchor := Search_Anchor;
            State.Mark_Active := Search_Mark;
         end Restore_Search;
         procedure Update_Search (Repeat : Boolean := False) is
            Backwards : constant Boolean :=
              State.Prompt_Kind = Search_Backward;
         begin
            if State.Field = Title_Field then
               Search
                 (State.Title,
                  To_Wide_Wide_String (State.Prompt),
                  (if Repeat
                   then Diary_Editor.Position (State.Title)
                   else Search_Origin),
                  Backwards,
                  not Repeat or else State.Keymap = Diary_Keymaps.Emacs);
            else
               Search
                 (State.Content,
                  To_Wide_Wide_String (State.Prompt),
                  (if Repeat
                   then Diary_Editor.Position (State.Content)
                   else Search_Origin),
                  Backwards,
                  not Repeat or else State.Keymap = Diary_Keymaps.Emacs);
            end if;
         end Update_Search;
      begin
         if Event.Kind = Escape_Key
           or else (Event.Kind = Character_Key and then Event.Letter = Ctrl_G)
         then
            if Searching then
               if State.Keymap = Diary_Keymaps.Helix
                 or else Event.Kind /= Escape_Key
               then
                  Restore_Search;
                  Message ("Search cancelled");
               else
                  Last_Search := State.Prompt;
               end if;
            end if;
            State.Prompt_Shown := False;
         elsif Event.Kind = Character_Key then
            if Searching and then Event.Letter in Ctrl_S | Ctrl_R then
               State.Prompt_Kind :=
                 (if Event.Letter = Ctrl_R
                  then Search_Backward
                  else Search_Forward);
               if Length (State.Prompt) = 0 then
                  State.Prompt := Last_Search;
               end if;
               Update_Search (Repeat => True);
            else
               case Wide_Wide_Character'Pos (Event.Letter) is
                  when 8 | 127                       =>
                     if Command'Length = 0 then
                        if Searching then
                           Restore_Search;
                        end if;
                        State.Prompt_Shown := False;
                     else
                        State.Prompt :=
                          To_Unbounded_Wide_Wide_String
                            (Command (Command'First .. Command'Last - 1));
                        if Searching then
                           Restore_Search;
                           Update_Search;
                        end if;
                     end if;

                  when 10 | 13                       =>
                     State.Prompt_Shown := False;
                     if Searching then
                        if Length (State.Prompt) > 0 then
                           Last_Search := State.Prompt;
                        end if;
                     else
                        Run_Command (Command);
                     end if;

                  when 32 .. 126 | 160 .. 16#10FFFF# =>
                     Append (State.Prompt, Event.Letter);
                     if Searching then
                        Update_Search;
                     end if;

                  when others                        =>
                     null;
               end case;
            end if;
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

            when Open_Settings =>
               State.Settings_Keymap := State.Keymap;
               State.Draft_Bindings := State.Bindings;
               State.Settings_Page := Preset_View;
               State.Binding_Action := Diary_Bindings.Action_Id'First;
               State.Mode := Settings;
               Message ("");

            when Quit          =>
               Finished := True;
         end case;
      end Handle_Reading;
      procedure Handle_Settings is
         use Diary_Bindings;
         procedure Save_Settings is
         begin
            Screen.Save_Settings
              ((State.Settings_Keymap, State.Draft_Bindings));
            State.Keymap := State.Settings_Keymap;
            State.Bindings := State.Draft_Bindings;
            Binding_Pending := (others => <>);
            State.Mode := Reading;
            Message
              ("Settings saved. Keymap: "
               & Diary_Keymaps.Label (State.Keymap));
         exception
            when Error : others =>
               Message
                 ("Cannot save settings: "
                  & Ada.Characters.Conversions.To_Wide_Wide_String
                      (Ada.Exceptions.Exception_Message (Error)));
         end Save_Settings;
         procedure Advance (Forward : Boolean) is
         begin
            loop
               State.Binding_Action :=
                 Action_Id'Val
                   ((Action_Id'Pos (State.Binding_Action)
                     + (if Forward then 1 else Action_Id'Pos (Action_Id'Last)))
                    mod (Action_Id'Pos (Action_Id'Last) + 1));
               exit when
                 Supported (State.Settings_Keymap, State.Binding_Action);
            end loop;
         end Advance;
         procedure Commit_Binding (Value : Key_Sequence) is
            Candidate : Binding_Table := State.Draft_Bindings;
         begin
            Candidate (State.Settings_Keymap, State.Binding_Action) := Value;
            declare
               Error : constant String := Validate (Candidate);
            begin
               if Error /= "" then
                  Message
                    (Ada.Characters.Conversions.To_Wide_Wide_String (Error));
               else
                  State.Draft_Bindings := Candidate;
                  State.Settings_Page := Bindings_View;
                  Message ("Binding updated (not saved yet)");
               end if;
            end;
         end Commit_Binding;
         function Letter (Value : Wide_Wide_Character) return Boolean
         is (Event.Kind = Character_Key and then Event.Letter = Value);
      begin
         if State.Settings_Page = Change_View then
            if Event.Kind = Escape_Key or else Letter (Ctrl_G) then
               State.Settings_Page := Bindings_View;
               Message ("Binding change cancelled");
            elsif Event.Kind = Character_Key then
               case Wide_Wide_Character'Pos (Event.Letter) is
                  when 21                            =>
                     State.Binding_Text := Null_Unbounded_Wide_Wide_String;

                  when 8 | 127                       =>
                     if Length (State.Binding_Text) > 0 then
                        Delete
                          (State.Binding_Text,
                           Length (State.Binding_Text),
                           Length (State.Binding_Text));
                     end if;

                  when 10 | 13                       =>
                     begin
                        Commit_Binding
                          (Parse
                             (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
                                (To_Wide_Wide_String (State.Binding_Text))));
                     exception
                        when Error : others =>
                           Message
                             (Ada.Characters.Conversions.To_Wide_Wide_String
                                (Ada.Exceptions.Exception_Message (Error)));
                     end;

                  when 32 .. 126 | 160 .. 16#10FFFF# =>
                     if Length (State.Binding_Text) < 120 then
                        Append (State.Binding_Text, Event.Letter);
                     end if;

                  when others                        =>
                     null;
               end case;
            end if;
         elsif State.Settings_Page = Bindings_View then
            if Event.Kind = Escape_Key then
               State.Settings_Page := Preset_View;
               Message ("Draft retained; Enter saves, Esc discards");
            elsif Event.Kind = Up_Key
              or else Letter ('k')
              or else Letter (Ctrl_P)
            then
               Advance (False);
            elsif Event.Kind = Down_Key
              or else Letter ('j')
              or else Letter (Ctrl_N)
            then
               Advance (True);
            elsif Event.Kind in Left_Key | Right_Key then
               State.Settings_Keymap :=
                 (if Event.Kind = Left_Key
                  then Diary_Keymaps.Emacs
                  else Diary_Keymaps.Helix);
               State.Binding_Action := Action_Id'First;
            elsif Letter (Newline)
              or else Letter (Wide_Wide_Character'Val (13))
            then
               State.Binding_Text :=
                 Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode
                   (Image
                      (State.Draft_Bindings
                         (State.Settings_Keymap, State.Binding_Action)))
                 & Null_Unbounded_Wide_Wide_String;
               State.Settings_Page := Change_View;
               Message
                 ("Type key names; C-u clears; Enter validates; Esc cancels");
            elsif Letter ('R') then
               Commit_Binding
                 (Defaults (State.Settings_Keymap, State.Binding_Action));
            elsif Letter ('D') then
               declare
                  Original : constant Binding_Table := Defaults;
               begin
                  for Action in Action_Id loop
                     State.Draft_Bindings (State.Settings_Keymap, Action) :=
                       Original (State.Settings_Keymap, Action);
                  end loop;
                  Message ("Keymap defaults restored (not saved yet)");
               end;
            elsif Letter ('S') then
               Save_Settings;
            end if;
         elsif Event.Kind = Escape_Key then
            State.Mode := Reading;
            Message ("Settings cancelled");
         elsif Event.Kind in Left_Key | Up_Key then
            State.Settings_Keymap := Diary_Keymaps.Emacs;
         elsif Event.Kind in Right_Key | Down_Key then
            State.Settings_Keymap := Diary_Keymaps.Helix;
         elsif Event.Kind = Character_Key then
            case Event.Letter is
               when '1' | 'k' | 'h' | Ctrl_P               =>
                  State.Settings_Keymap := Diary_Keymaps.Emacs;

               when '2' | 'j' | 'l' | Ctrl_N               =>
                  State.Settings_Keymap := Diary_Keymaps.Helix;

               when 'b' | 'B'                              =>
                  State.Settings_Page := Bindings_View;
                  State.Binding_Action := Action_Id'First;
                  Message ("Enter changes a binding; S saves all changes");

               when Newline | Wide_Wide_Character'Val (13) =>
                  Save_Settings;

               when others                                 =>
                  null;
            end case;
         end if;
      end Handle_Settings;
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

               when Settings                         =>
                  Handle_Settings;

               when Confirm_Delete | Confirm_Discard =>
                  Handle_Confirmation;
            end case;
         end if;
      end Dispatch;
      procedure Process_Input;
      procedure Deliver (Value : Input_Event) is
      begin
         Event := Value;
         if State.Keymap = Diary_Keymaps.Helix
           and then Event.Kind = Meta_Key
           and then (State.Modal = Insert_Mode
                     or else Event.Letter not in ';' | '.')
         then
            declare
               Letter : constant Wide_Wide_Character := Event.Letter;
            begin
               Event := (Escape_Key, ' ');
               Dispatch;
               Event := (Character_Key, Letter);
               Process_Input;
            end;
         else
            Dispatch;
         end if;
      end Deliver;
      procedure Process_Input is
         use Diary_Bindings;
         Context     : Input_Context;
         Match       : Match_Kind;
         Action      : Action_Id;
         Alias_Found : Boolean;
         Incoming    : Input_Event := Event;
         Had_Prefix  : constant Boolean := Binding_Pending.Length > 0;
      begin
         if not Screen.Is_Usable
           or else State.Mode not in Reading | Editing
           or else State.Prompt_Shown
           or else Pending_Find /= ' '
         then
            Binding_Pending := (others => <>);
            Deliver (Incoming);
            return;
         elsif Incoming.Kind = Resize_Key then
            Dispatch;
            return;
         elsif Had_Prefix
           and then (Incoming.Kind = Escape_Key
                     or else (Incoming.Kind = Character_Key
                              and then Incoming.Letter = Ctrl_G))
         then
            Binding_Pending := (others => <>);
            Prefix := No_Prefix;
            Count := 0;
            Message ("Key sequence cancelled");
            return;
         end if;
         Context :=
           (if State.Mode = Reading
            then Calendar_Context
            elsif State.Keymap = Diary_Keymaps.Emacs
            then Emacs_Context
            elsif State.Modal = Insert_Mode
            then Helix_Insert_Context
            else Helix_Normal_Context);
         if not Had_Prefix
           and then Context = Helix_Normal_Context
           and then Incoming.Kind = Character_Key
           and then Incoming.Letter in '0' .. '9'
         then
            Deliver (Incoming);
            return;
         end if;
         if Incoming.Kind in Character_Key | Meta_Key
           and then Incoming.Letter = Backspace_Key
         then
            Incoming.Letter := Rubout_Key;
         elsif Incoming.Kind = Character_Key and then Incoming.Letter = Newline
         then
            Incoming.Letter := Wide_Wide_Character'Val (13);
         end if;
         if Binding_Pending.Length = Max_Keys then
            Binding_Pending := (others => <>);
         end if;
         Binding_Pending.Length := Binding_Pending.Length + 1;
         Binding_Pending.Keys (Binding_Pending.Length) := Incoming;
         Resolve
           (State.Bindings,
            State.Keymap,
            Context,
            Binding_Pending,
            Match,
            Action);
         if Match = No_Match then
            Resolve_Alias
              (State.Keymap, Context, Binding_Pending, Alias_Found, Action);
            if Alias_Found then
               Match :=
                 (if State.Bindings (State.Keymap, Action)
                    = Defaults (State.Keymap, Action)
                  then Action_Match
                  else Disabled_Match);
            end if;
         end if;
         case Match is
            when Prefix_Match   =>
               Message
                 ("Keys: "
                  & Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode
                      (Image (Binding_Pending)));

            when Action_Match   =>
               Binding_Pending := (others => <>);
               declare
                  Keys : constant Key_Sequence :=
                    Canonical (State.Keymap, Action);
               begin
                  for Index in 1 .. Keys.Length loop
                     Deliver (Keys.Keys (Index));
                  end loop;
               end;

            when Disabled_Match =>
               Binding_Pending := (others => <>);
               Prefix := No_Prefix;
               Count := 0;
               Message ("Binding changed or disabled; see S settings");

            when No_Match       =>
               Binding_Pending := (others => <>);
               if Had_Prefix then
                  Prefix := No_Prefix;
                  Count := 0;
                  Message ("Unbound key sequence");
               else
                  Deliver (Incoming);
               end if;
         end case;
      end Process_Input;
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
      State.Bindings := Bindings;
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
            Process_Input;
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
