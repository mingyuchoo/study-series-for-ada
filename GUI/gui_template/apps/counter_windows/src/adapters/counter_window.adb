with Ada.Strings;
with Ada.Strings.Fixed;
with Counter_Actions;
with GWindows.Application;
with GWindows.Base;
with GWindows.Buttons;
with GWindows.GStrings;
with GWindows.Static_Controls;
with GWindows.Windows.Main;

package body Counter_Window is
   procedure Run is
      use Counter_Actions;

      Window : GWindows.Windows.Main.Main_Window_Type;
      Count_Label : GWindows.Static_Controls.Label_Type;
      Increment_Button : GWindows.Buttons.Button_Type;
      Reset_Button : GWindows.Buttons.Button_Type;
      Value : Count := Initial_Count;

      function Count_Text return GWindows.GString is
        (GWindows.GStrings.To_GString_From_String
           (Ada.Strings.Fixed.Trim (Value'Image, Ada.Strings.Left)));

      procedure Dispatch (Event : Action) is
      begin
         Value := Apply (Value, Event);
         GWindows.Static_Controls.Text (Count_Label, Count_Text);
      end Dispatch;

      procedure Increment_Click (Sender : in out GWindows.Base.Base_Window_Type'Class) is
         pragma Unreferenced (Sender);
      begin
         Dispatch (Increment);
      end Increment_Click;

      procedure Reset_Click (Sender : in out GWindows.Base.Base_Window_Type'Class) is
         pragma Unreferenced (Sender);
      begin
         Dispatch (Reset);
      end Reset_Click;
   begin
      GWindows.Windows.Main.Create (Window, "Counter", Width => 300, Height => 160);
      GWindows.Windows.Main.Keyboard_Support (Window, True);
      GWindows.Static_Controls.Create
        (Count_Label, Window, Count_Text, 12, 16, 260, 26,
         Alignment => GWindows.Static_Controls.Center);
      GWindows.Buttons.Create (Increment_Button, Window, "&Increment", 40, 56, 100, 32);
      GWindows.Buttons.Create (Reset_Button, Window, "&Reset", 148, 56, 100, 32);
      GWindows.Buttons.On_Click_Handler (Increment_Button, Increment_Click'Unrestricted_Access);
      GWindows.Buttons.On_Click_Handler (Reset_Button, Reset_Click'Unrestricted_Access);
      GWindows.Windows.Main.Visible (Window, True);
      GWindows.Application.Message_Loop;
   end Run;
end Counter_Window;
