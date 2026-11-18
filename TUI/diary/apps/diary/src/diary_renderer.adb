with Ada.Characters.Conversions;
with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Dates;
with Diary_Editor;
with Diary_Keymaps;
with Diary_Text;
with Malef.Groups;
with Malef.Surfaces;
with Malef.Window;

package body Diary_Renderer is
   use Malef;
   use Diary_Screen_State;
   use Ada.Strings.Wide_Wide_Unbounded;
   use type Diary_Dates.Date;
   use type Diary_Keymaps.Kind;
   Background : constant RGBA_Type := "#101820";
   Foreground : constant RGBA_Type := "#D6DEE8";
   Muted      : constant RGBA_Type := "#7E95AB";
   Accent     : constant RGBA_Type := "#61D6B1";
   Panel      : constant RGBA_Type := "#1C2C3A";
   Selection  : constant RGBA_Type := "#486078";
   function Wide (Value : String) return Wide_Wide_String
   renames Ada.Characters.Conversions.To_Wide_Wide_String;
   function Is_Usable return Boolean is
      Rows : Positive_Row_Count;
      Cols : Positive_Col_Count;
   begin
      Malef.Window.Window.Get_Dimensions (Rows, Cols);
      return Rows >= 27 and then Cols >= 80;
   end Is_Usable;
   function Preview_Width return Positive is
      Rows : Positive_Row_Count;
      Cols : Positive_Col_Count;
   begin
      Malef.Window.Window.Get_Dimensions (Rows, Cols);
      return Positive'Max (1, Integer (Cols) - 40);
   end Preview_Width;
   procedure Display (State : Diary_Screen_State.State) is
      Rows : Positive_Row_Count;
      Cols : Positive_Col_Count;
   begin
      Malef.Window.Window.Get_Dimensions (Rows, Cols);
      if Rows < 1 or else Cols < 1 then
         return;
      end if;
      declare
         Surface : Surfaces.Surface (Rows, Cols);
         procedure Put
           (Row, Col : Positive;
            Text     : Wide_Wide_String;
            Colour   : RGBA_Type := Foreground)
         is
            X     : Natural := Col;
            Width : Positive;
         begin
            if Row > Natural (Rows) then
               return;
            end if;
            for Letter of Text loop
               Width := Diary_Text.Cell_Width (Letter);
               exit when X + Width - 1 > Natural (Cols);
               Surface.Set (Row_Type (Row), Col_Type (X), Letter);
               Surface.Fill_Foreground
                 ((Row_Type (Row), Col_Type (X)),
                  (Row_Type (Row), Col_Type (X + Width - 1)),
                  Colour);
               if Width = 2 then
                  Surface.Set (Row_Type (Row), Col_Type (X + 1), Dbl);
               end if;
               X := X + Width;
            end loop;
         end Put;
         procedure Highlight (Row, Col, Width : Positive; Colour : RGBA_Type)
         is
         begin
            if Row <= Natural (Rows) and then Col + Width - 1 <= Natural (Cols)
            then
               Surface.Fill_Background
                 ((Row_Type (Row), Col_Type (Col)),
                  (Row_Type (Row), Col_Type (Col + Width - 1)),
                  Colour);
            end if;
         end Highlight;
         procedure Paragraph
           (Value                   : Wide_Wide_String;
            Row, Col, Width, Height : Positive;
            Scroll                  : Natural := 0;
            Cursor                  : Integer := -1;
            Select_From, Select_To  : Natural := 0)
         is
            Position : Diary_Text.Cell_Position;
            Size     : Positive;
            procedure Mark_Cursor (Offset : Natural; Cells : Positive := 1) is
               Location : constant Diary_Text.Cell_Position :=
                 (if Position.Col >= Width
                  then (Position.Row + 1, 0)
                  else Position);
            begin
               if Location.Row < Scroll or else Location.Row >= Scroll + Height
               then
                  null;
               elsif Integer (Offset) = Cursor then
                  Highlight
                    (Row + Location.Row - Scroll,
                     Col + Location.Col,
                     1,
                     Accent);
               elsif Cursor >= 0
                 and then Offset >= Select_From
                 and then Offset < Select_To
               then
                  Highlight
                    (Row + Location.Row - Scroll,
                     Col + Location.Col,
                     Cells,
                     Selection);
               end if;
            end Mark_Cursor;
         begin
            for Index in Value'Range loop
               Size := Diary_Text.Cell_Width (Value (Index));
               if Wide_Wide_Character'Pos (Value (Index)) /= 10
                 and then Position.Col + Size > Width
               then
                  Position := (Position.Row + 1, 0);
               end if;
               Mark_Cursor (Index - Value'First, Size);
               if Position.Row >= Scroll
                 and then Position.Row < Scroll + Height
                 and then Wide_Wide_Character'Pos (Value (Index)) /= 10
               then
                  Put
                    (Row + Position.Row - Scroll,
                     Col + Position.Col,
                     [1 =>
                        (if Wide_Wide_Character'Pos (Value (Index)) = 9
                         then ' '
                         else Value (Index))]);
               end if;
               Diary_Text.Advance (Position, Value (Index), Width);
               exit when Position.Row >= Scroll + Height;
            end loop;
            Mark_Cursor (Value'Length);
         end Paragraph;
         procedure Calendar is
            First          : constant Diary_Dates.Date :=
              Diary_Dates.Create
                (Diary_Dates.Year (State.Selected),
                 Diary_Dates.Month (State.Selected),
                 1);
            Offset         : constant Natural := Diary_Dates.Weekday (First);
            Slot, Row, Col : Natural;
            Label          : Wide_Wide_String (1 .. 4);
            Current        : Diary_Dates.Date;
         begin
            Put
              (5,
               3,
               Wide (Diary_Dates.Image (State.Selected) (1 .. 7)),
               Accent);
            Put (7, 3, "Mo   Tu   We   Th   Fr   Sa   Su", Muted);
            for Day in
              1
              .. Diary_Dates.Days_In_Month
                   (Diary_Dates.Year (First), Diary_Dates.Month (First))
            loop
               Slot := Offset + Day - 1;
               Row := 9 + Slot / 7 * 2;
               Col := 3 + Slot mod 7 * 5;
               Current :=
                 Diary_Dates.Create
                   (Diary_Dates.Year (First), Diary_Dates.Month (First), Day);
               Label :=
                 (if Day >= 10
                  then Wide_Wide_Character'Val (48 + Day / 10)
                  else ' ')
                 & Wide_Wide_Character'Val (48 + Day mod 10)
                 & (if State.Markers (Day) then '*' else ' ')
                 & ' ';
               Put
                 (Row,
                  Col,
                  Label,
                  (if Current = State.Today then Accent else Foreground));
               if Current = State.Selected then
                  Highlight (Row, Col, 4, [72, 96, 120, 255]);
               end if;
            end loop;
            Put (22, 3, "* entry    green: today", Muted);
            Put (24, 3, "[ / ] previous / next month", Muted);
         end Calendar;
         procedure Editor is
            Width        : constant Positive := Positive (Cols) - 6;
            Height       : constant Positive := Positive (Rows) - 13;
            Body_Text    : constant Wide_Wide_String :=
              Diary_Editor.Text (State.Content);
            Cursor       : constant Natural :=
              Diary_Editor.Position (State.Content);
            Location     : constant Diary_Text.Cell_Position :=
              Diary_Text.Position_At (Body_Text, Cursor, Width);
            Body_Scroll  : constant Natural :=
              Natural'Max (Location.Row, Height - 1) - (Height - 1);
            Title_Text   : constant Wide_Wide_String :=
              Diary_Editor.Text (State.Title);
            Title_Cursor : constant Natural :=
              Diary_Editor.Position (State.Title);
            Title_Row    : constant Natural :=
              Diary_Text.Position_At (Title_Text, Title_Cursor, Width).Row;
         begin
            Put
              (5,
               3,
               (if State.Was_Existing then "EDIT ENTRY" else "NEW ENTRY"),
               Accent);
            Put (5, 20, Wide (Diary_Dates.Image (State.Selected)), Muted);
            Put
              (7,
               3,
               (if State.Field = Title_Field
                then "Title [active]"
                else "Title"),
               Muted);
            Paragraph
              (Title_Text,
               8,
               3,
               Width,
               1,
               Title_Row,
               (if State.Field = Title_Field
                then Integer (Title_Cursor)
                else -1),
               State.Select_From,
               State.Select_To);
            Put
              (10,
               3,
               (if State.Field = Body_Field then "Body [active]" else "Body"),
               Muted);
            Paragraph
              (Body_Text,
               11,
               3,
               Width,
               Height,
               Body_Scroll,
               (if State.Field = Body_Field then Integer (Cursor) else -1),
               State.Select_From,
               State.Select_To);
            if State.Keymap = Diary_Keymaps.Helix then
               Put
                 (5,
                  34,
                  (case State.Modal is
                     when Normal_Mode => "NOR",
                     when Insert_Mode => "INS",
                     when Select_Mode => "SEL"),
                  Accent);
               Put
                 (Positive (Rows) - 2,
                  3,
                  "i/a/o insert  Esc normal  hjkl move  w/b/e word  x line  v select  % all",
                  Muted);
               Put
                 (Positive (Rows) - 1,
                  3,
                  "d/c/y/p edit  u/U undo  Tab field  :w save  :wq save+close  :q close  :q!",
                  Muted);
            else
               Put
                 (Positive (Rows) - 2,
                  3,
                  "Tab field  Ctrl+S save  C-x C-s save+stay  Esc cancel  C-/ undo  M-f/b word",
                  Muted);
               Put
                 (Positive (Rows) - 1,
                  3,
                  "C-a/e line  C-k kill  C-Space mark  C-w cut  M-w copy  C-y yank  M-</> ends",
                  Muted);
            end if;
         end Editor;
      begin
         Surface.Fill (' ');
         Surface.Fill_Background (Background);
         Surface.Fill_Foreground (Foreground);
         if Rows < 27 or else Cols < 80 then
            Put (1, 1, "Resize terminal to at least 80 x 27.", Accent);
         else
            Highlight (1, 1, Positive (Cols), Panel);
            Highlight (2, 1, Positive (Cols), Panel);
            Put (2, 3, "ADA DIARY", Accent);
            Put (2, 18, "A little space for every day", Muted);
            if State.Mode in Editing | Confirm_Discard then
               Editor;
            else
               Calendar;
               for Row in 4 .. Natural (Rows) - 4 loop
                  Put (Row, 38, "│", Panel);
               end loop;
               Put (5, 41, Wide (Diary_Dates.Image (State.Selected)), Accent);
               if State.Read_Failed then
                  Put (8, 41, "Unable to read this entry.", Muted);
               elsif State.Exists then
                  Paragraph
                    (To_Wide_Wide_String (State.Item.Title),
                     7,
                     41,
                     Positive (Cols) - 42,
                     2);
                  Paragraph
                    (To_Wide_Wide_String (State.Item.Content),
                     10,
                     41,
                     Preview_Width - 2,
                     Positive (Rows) - 14,
                     State.Scroll);
               else
                  Put (8, 41, "No entry for this day.", Muted);
                  Put (10, 41, "Press N to start writing.", Accent);
               end if;
               Put
                 (Positive (Rows) - 2,
                  3,
                  (if State.Keymap = Diary_Keymaps.Helix
                   then
                     "hjkl date  [/] month  T today  N new  E/I edit  D delete  C-d/C-u scroll  Q/:q"
                   else
                     "Arrows date  [/] month  T today  N new  E edit  D delete  J/K scroll  Q quit"),
                  Muted);
               Put
                 (Positive (Rows) - 1,
                  3,
                  "Keymap: "
                  & Diary_Keymaps.Label (State.Keymap)
                  & "  (M switches Emacs / Helix)",
                  Muted);
            end if;
            if State.Mode = Confirm_Delete then
               Highlight (Positive (Rows) - 4, 2, Positive (Cols) - 2, Panel);
               Put
                 (Positive (Rows) - 4,
                  3,
                  "Delete this entry?  Y delete / N cancel",
                  Accent);
            elsif State.Mode = Confirm_Discard then
               Highlight (Positive (Rows) - 4, 2, Positive (Cols) - 2, Panel);
               Put
                 (Positive (Rows) - 4,
                  3,
                  "Discard changes?  Y discard / N keep editing",
                  Accent);
            end if;
            Put
              (Positive (Rows),
               3,
               (if State.Prompt_Shown
                then ":" & To_Wide_Wide_String (State.Prompt)
                else To_Wide_Wide_String (State.Message)),
               Accent);
         end if;
         declare
            Group : constant Groups.Group := [Groups.Layer (Surface)];
         begin
            Malef.Window.Window.Set_Group (Group);
            Malef.Window.Window.Display;
         end;
      end;
   end Display;
end Diary_Renderer;
