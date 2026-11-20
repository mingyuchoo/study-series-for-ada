with Ada.Text_IO;
with Diary_Calendar_Commands;
with Diary_Bindings;
with Diary_Input;
with Diary_Keymaps;

procedure Calendar_Commands_Tests is
   use Diary_Calendar_Commands;
   use Diary_Input;
   use Diary_Keymaps;
begin
   pragma Assert (Resolve ((Left_Key, ' '), Emacs) = Day_Back);
   pragma Assert (Resolve ((Meta_Key, '}'), Helix) = Month_Forward);
   pragma Assert (Resolve ((Character_Key, 'j'), Emacs) = Scroll_Down);
   pragma Assert (Resolve ((Character_Key, 'j'), Helix) = Week_Forward);
   pragma Assert (Resolve ((Character_Key, ':'), Helix) = Open_Prompt);
   pragma Assert (Resolve ((Character_Key, ':'), Emacs) = No_Command);
   pragma Assert (Resolve ((Resize_Key, 'q'), Emacs) = No_Command);
   declare
      use Diary_Bindings;
      Table  : Binding_Table := Defaults;
      Match  : Match_Kind;
      Action : Action_Id;
      Found  : Boolean;
      procedure Reject (Text : String) is
         Value : Key_Sequence;
      begin
         Value := Parse (Text);
         raise Program_Error with "Accepted invalid key: " & Image (Value);
      exception
         when Invalid_Binding =>
            null;
      end Reject;
   begin
      pragma Assert (Validate (Table) = "");
      Table (Emacs, Save_Entry) := Parse ("C-x s");
      pragma Assert (Validate (Table) = "");
      Diary_Bindings.Resolve
        (Table, Emacs, Emacs_Context, Parse ("C-x"), Match, Action);
      pragma Assert (Match = Prefix_Match);
      Diary_Bindings.Resolve
        (Table, Emacs, Emacs_Context, Parse ("C-x s"), Match, Action);
      pragma Assert (Match = Action_Match and then Action = Save_Entry);
      Diary_Bindings.Resolve
        (Table, Emacs, Emacs_Context, Parse ("C-x C-s"), Match, Action);
      pragma Assert (Match = Disabled_Match);
      Resolve_Alias (Emacs, Emacs_Context, Parse ("M-F"), Found, Action);
      pragma Assert (Found and then Action = Word_Forward);
      Resolve_Alias (Emacs, Calendar_Context, Parse ("Q"), Found, Action);
      pragma Assert (Found and then Action = Calendar_Quit);
      Resolve_Alias (Emacs, Emacs_Context, Parse ("C-x K"), Found, Action);
      pragma Assert (Found and then Action = Close_Entry);
      Resolve_Alias (Emacs, Emacs_Context, Parse ("Left"), Found, Action);
      pragma Assert (Found and then Action = Move_Left);
      Resolve_Alias
        (Helix, Helix_Normal_Context, Parse ("C-a"), Found, Action);
      pragma Assert (Found and then Action = Line_Start);
      Table (Helix, Save_Entry) := Parse ("h");
      pragma Assert (Validate (Table) /= "");
      Table (Helix, Save_Entry) := Parse ("C-s");
      pragma Assert (Validate (Table) = "");
      Table (Helix, Move_Left) := Parse ("g");
      pragma Assert (Validate (Table) /= "");
      Table := Defaults;
      Table (Helix, Move_Left) := Parse ("3");
      pragma Assert (Validate (Table) /= "");
      Table := Defaults;
      Table (Emacs, Save_Entry) := Parse ("M-z Esc");
      pragma Assert (Validate (Table) /= "");
      Table := Defaults;
      Table (Emacs, Save_Entry) := Parse ("M-z C-g");
      pragma Assert (Validate (Table) /= "");
      Table := Defaults;
      Table (Emacs, Save_Entry) := Parse ("");
      pragma Assert (Validate (Table) = "");
      pragma Assert (Image (Parse ("C-x   C-Space")) = "C-x C-Space");
      pragma Assert (Image (Parse ("M-Backspace")) = "M-Backspace");
      pragma Assert (Image (Parse ("C-h")) = "Backspace");
      pragma Assert (Image (Parse ("C-j")) = "Enter");
      Reject ("M-[");
      Reject ("M-O");
      Reject ("C-c");
      Reject ("C-z");
      Reject ("a b c d e");
      Reject ("F99");
      Table := Defaults;
      Table (Emacs, Save_Entry) := Parse ("C-b");
      Table (Emacs, Move_Left) := Parse ("C-x C-s");
      pragma Assert (Validate (Table) = "");
      Table := Defaults;
      Table (Emacs, Save_Entry) := Parse ("C-j");
      pragma Assert (Validate (Table) /= "");
   end;
   Ada.Text_IO.Put_Line ("PASS calendar commands for Emacs and Helix");
end Calendar_Commands_Tests;
