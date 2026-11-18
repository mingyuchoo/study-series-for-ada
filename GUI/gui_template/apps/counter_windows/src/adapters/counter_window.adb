with Ada.Strings;
with Ada.Strings.Fixed;
with Counter_Actions;
with GWindows.Application;
with GWindows.Base;
with GWindows.Buttons;
with GWindows.Buttons.Owner_Drawn;
with GWindows.Colors;
with GWindows.Drawing;
with GWindows.Drawing_Objects;
with GWindows.GStrings;
with GWindows.Static_Controls;
with GWindows.Types;
with GWindows.Windows.Main;

package body Counter_Window is
   procedure Run is
      use Counter_Actions;
      use type Count;

      Window : GWindows.Windows.Main.Main_Window_Type;
      Heading_Label : GWindows.Static_Controls.Label_Type;
      Subtitle_Label : GWindows.Static_Controls.Label_Type;
      Caption_Label : GWindows.Static_Controls.Label_Type;
      Count_Label : GWindows.Static_Controls.Label_Type;
      Range_Label : GWindows.Static_Controls.Label_Type;
      Status_Label : GWindows.Static_Controls.Label_Type;
      Increment_Button : GWindows.Buttons.Owner_Drawn.Owner_Drawn_Button_Type;
      Reset_Button : GWindows.Buttons.Button_Type;
      Body_Font : GWindows.Drawing_Objects.Font_Type;
      Heading_Font : GWindows.Drawing_Objects.Font_Type;
      Count_Font : GWindows.Drawing_Objects.Font_Type;
      Small_Font : GWindows.Drawing_Objects.Font_Type;
      Canvas : GWindows.Drawing.Canvas_Type;
      Pixels_Per_Inch : Positive := 96;
      Value : Count := Initial_Count;

      function Scaled (Pixels : Integer) return Integer is
        (Pixels * Pixels_Per_Inch / 96);

      function Count_Text return GWindows.GString is
        (GWindows.GStrings.To_GString_From_String
           (Ada.Strings.Fixed.Trim (Value'Image, Ada.Strings.Left)));

      procedure Dispatch (Event : Action) is
      begin
         Value := Apply (Value, Event);
         GWindows.Static_Controls.Text (Count_Label, Count_Text);
         Increment_Button.Enabled (Value < Count'Last);
         if Value = Count'Last then
            Status_Label.Text ("Maximum reached (999). Reset to start again.");
            Reset_Button.Focus;
         else
            Status_Label.Text ("Ready when you are.");
            if Event = Reset then
               Increment_Button.Focus;
            end if;
         end if;
      end Dispatch;

      procedure Paint_Increment
        (Control : in out GWindows.Base.Base_Window_Type'Class;
         Button_Canvas : in out GWindows.Drawing.Canvas_Type;
         Area : GWindows.Types.Rectangle_Type;
         Selected : Boolean;
         Focused : Boolean)
      is
         use GWindows.Colors;
         use GWindows.Drawing;

         Background : constant Color_Type :=
           (if not Control.Enabled then To_Color (226, 232, 240)
            elsif Selected then To_Color (30, 64, 175)
            else To_Color (37, 99, 235));
         Foreground : constant Color_Type :=
           (if Control.Enabled then White else To_Color (100, 116, 139));
         Brush : GWindows.Drawing_Objects.Brush_Type;
         Text_Size : GWindows.Types.Size_Type;
      begin
         GWindows.Drawing_Objects.Create_Solid_Brush (Brush, Background);
         Fill_Rectangle (Button_Canvas, Area, Brush);
         Select_Object (Button_Canvas, Body_Font);
         Text_Color (Button_Canvas, Foreground);
         Background_Mode (Button_Canvas, Transparent);
         Text_Size := Text_Output_Size (Button_Canvas, "Increment +1");
         Put
           (Button_Canvas,
            (Area.Left + Area.Right - Text_Size.Width) / 2,
            (Area.Top + Area.Bottom - Text_Size.Height) / 2,
            "Increment +1");
         if Focused then
            GWindows.Drawing_Objects.Create_Solid_Brush (Brush, White);
            Frame_Rectangle
              (Button_Canvas,
               (Area.Left + Scaled (4), Area.Top + Scaled (4),
                Area.Right - Scaled (4), Area.Bottom - Scaled (4)),
               Brush);
         end if;
      end Paint_Increment;

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
      Window.Create_As_Dialog ("Counter");
      Window.Get_Canvas (Canvas);
      Pixels_Per_Inch := GWindows.Drawing.X_Pixels_Per_Inch (Canvas);
      Window.Client_Area_Size (Scaled (420), Scaled (410));
      Window.Keyboard_Support (True);
      GWindows.Drawing_Objects.Create_Font (Body_Font, "Segoe UI", -Scaled (16));
      GWindows.Drawing_Objects.Create_Font
        (Heading_Font, "Segoe UI", -Scaled (28), GWindows.Drawing_Objects.FW_SEMIBOLD);
      GWindows.Drawing_Objects.Create_Font
        (Count_Font, "Segoe UI", -Scaled (76), GWindows.Drawing_Objects.FW_SEMIBOLD);
      GWindows.Drawing_Objects.Create_Font (Small_Font, "Segoe UI", -Scaled (14));
      GWindows.Static_Controls.Create
        (Heading_Label, Window, "Counter", Scaled (28), Scaled (24), Scaled (364), Scaled (40));
      GWindows.Static_Controls.Create
        (Subtitle_Label, Window, "A little focus. One step at a time.",
         Scaled (28), Scaled (68), Scaled (364), Scaled (24));
      GWindows.Static_Controls.Create
        (Caption_Label, Window, "CURRENT COUNT", Scaled (28), Scaled (116),
         Scaled (364), Scaled (22), Alignment => GWindows.Static_Controls.Center);
      GWindows.Static_Controls.Create
        (Count_Label, Window, Count_Text, Scaled (28), Scaled (140), Scaled (364), Scaled (92),
         Alignment => GWindows.Static_Controls.Center);
      GWindows.Static_Controls.Create
        (Range_Label, Window, "0 - 999", Scaled (28), Scaled (240),
         Scaled (364), Scaled (22), Alignment => GWindows.Static_Controls.Center);
      Increment_Button.Create
        (Window, "&Increment +1", Scaled (28), Scaled (290), Scaled (244), Scaled (48));
      Reset_Button.Create
        (Window, "&Reset", Scaled (284), Scaled (290), Scaled (108), Scaled (48));
      GWindows.Static_Controls.Create
        (Status_Label, Window, "Ready when you are.", Scaled (28), Scaled (354),
         Scaled (364), Scaled (44), Alignment => GWindows.Static_Controls.Center);
      Heading_Label.Set_Font (Heading_Font);
      Subtitle_Label.Set_Font (Body_Font);
      Caption_Label.Set_Font (Small_Font);
      Count_Label.Set_Font (Count_Font);
      Range_Label.Set_Font (Small_Font);
      Status_Label.Set_Font (Small_Font);
      Increment_Button.Set_Font (Body_Font);
      Reset_Button.Set_Font (Body_Font);
      Increment_Button.On_Paint_Handler (Paint_Increment'Unrestricted_Access);
      Increment_Button.On_Click_Handler (Increment_Click'Unrestricted_Access);
      Reset_Button.On_Click_Handler (Reset_Click'Unrestricted_Access);
      Window.Center;
      Window.Visible (True);
      Increment_Button.Focus;
      GWindows.Application.Message_Loop;
   end Run;
end Counter_Window;
