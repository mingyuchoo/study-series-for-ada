with Diary_Input;
with Diary_Keymaps;

package Diary_Bindings is
   Invalid_Binding : exception;
   Max_Keys        : constant := 4;
   type Event_Array is
     array (Positive range 1 .. Max_Keys) of Diary_Input.Input_Event;
   type Key_Sequence is record
      Length : Natural range 0 .. Max_Keys := 0;
      Keys   : Event_Array := [others => (others => <>)];
   end record;
   type Action_Id is
     (Save_Entry,
      Close_Entry,
      Save_And_Close,
      Discard_Entry,
      Switch_Field,
      Move_Left,
      Move_Right,
      Move_Up,
      Move_Down,
      Line_Start,
      Line_End,
      Word_Forward,
      Word_Backward,
      Word_End,
      Buffer_Start,
      Buffer_End,
      Delete_Forward,
      Delete_Backward,
      New_Line,
      Kill_Word_Forward,
      Kill_Word_Backward,
      Kill_Line,
      Set_Mark,
      Cut_Region,
      Copy_Region,
      Yank,
      Yank_Previous,
      Undo,
      Undo_Alternate,
      Exchange_Mark,
      Page_Down,
      Page_Up,
      Search_Forward,
      Search_Backward,
      Cancel_Command,
      Select_Line,
      Select_All,
      Collapse_Selection,
      Select_Mode,
      Insert_Before,
      Insert_After,
      Insert_Line_Start,
      Insert_Line_End,
      Open_Below,
      Open_Above,
      Delete_Selection,
      Change_Selection,
      Copy_Selection,
      Paste_After,
      Paste_Before,
      Redo,
      Open_Command,
      Find_Forward,
      Find_Backward,
      Till_Forward,
      Till_Backward,
      Repeat_Find,
      Replace_Selection,
      Flip_Selection,
      Search_Next,
      Search_Previous,
      Normal_Mode,
      Insert_Left,
      Insert_Right,
      Insert_Up,
      Insert_Down,
      Insert_Start,
      Insert_End,
      Calendar_New,
      Calendar_Edit,
      Calendar_Delete,
      Calendar_Settings,
      Calendar_Quit,
      Calendar_Left,
      Calendar_Right,
      Calendar_Up,
      Calendar_Down,
      Calendar_Previous_Month,
      Calendar_Next_Month,
      Calendar_Today,
      Calendar_Scroll_Down,
      Calendar_Scroll_Up,
      Calendar_Switch_Keymap,
      Calendar_Command);
   type Binding_Table is array (Diary_Keymaps.Kind, Action_Id) of Key_Sequence;
   function Parse (Value : String) return Key_Sequence;
   function Image (Value : Key_Sequence) return String;
   function Name (Action : Action_Id) return String;
   function Action_Named (Value : String) return Action_Id;
   function Canonical
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id) return Key_Sequence;
   function Defaults return Binding_Table;
   type Preferences is record
      Keymap   : Diary_Keymaps.Kind := Diary_Keymaps.Emacs;
      Bindings : Binding_Table := Defaults;
   end record;
   type Input_Context is
     (Calendar_Context,
      Emacs_Context,
      Helix_Normal_Context,
      Helix_Insert_Context);
   function Applies
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id; Context : Input_Context)
      return Boolean;
   function Supported
     (Keymap : Diary_Keymaps.Kind; Action : Action_Id) return Boolean;
   function Validate (Value : Binding_Table) return String;
   type Match_Kind is (No_Match, Prefix_Match, Action_Match, Disabled_Match);
   procedure Resolve_Alias
     (Keymap   : Diary_Keymaps.Kind;
      Context  : Input_Context;
      Sequence : Key_Sequence;
      Found    : out Boolean;
      Action   : out Action_Id);
   procedure Resolve
     (Value    : Binding_Table;
      Keymap   : Diary_Keymaps.Kind;
      Context  : Input_Context;
      Sequence : Key_Sequence;
      Match    : out Match_Kind;
      Action   : out Action_Id);
end Diary_Bindings;
