with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Tui_Input;
with Tui_Model;
with Tui_Renderer;
with Tui_Terminal;

procedure Tui_Template is
   use Ada.Command_Line;
   use type Tui_Model.State;

   Terminal : aliased Tui_Terminal.Session;
   State    : Tui_Model.State := Tui_Model.Idle;
   Event    : Tui_Input.Input_Event;
begin
   if Argument_Count = 1 and then Argument (1) in "--help" | "-h" then
      Ada.Text_IO.Put_Line ("Usage: tui_template [--help]");
      Ada.Text_IO.Put_Line ("Space toggles the sample state. Q exits.");
      return;
   elsif Argument_Count /= 0 then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "Usage: tui_template [--help]");
      Set_Exit_Status (Failure);
      return;
   end if;

   Tui_Terminal.Start (Terminal);
   while State /= Tui_Model.Quit loop
      Tui_Renderer.Display (State);
      Tui_Terminal.Next (Terminal, Event);
      State := Tui_Model.Update (State, Event);
   end loop;
   Tui_Terminal.Stop (Terminal);
exception
   when Error : others =>
      Tui_Terminal.Stop (Terminal);
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "tui_template: " & Ada.Exceptions.Exception_Message (Error));
      Set_Exit_Status (Failure);
end Tui_Template;
