with Malef.Groups;
with Malef.Surfaces;
with Malef.Window;

package body Tui_Renderer is
   use Malef;

   procedure Display (State : Tui_Model.State) is
      Rows    : Positive_Row_Count;
      Columns : Positive_Col_Count;
   begin
      Window.Window.Get_Dimensions (Rows, Columns);
      if Rows < 1 or else Columns < 1 then
         return;
      end if;

      declare
         Surface : Surfaces.Surface (Rows, Columns);

         procedure Put (Row : Positive; Text : Wide_Wide_String) is
         begin
            if Row <= Natural (Rows) then
               for Column in 1 .. Natural'Min (Natural (Columns), Text'Length)
               loop
                  Surface.Set
                    (Row_Type (Row),
                     Col_Type (Column),
                     Text (Text'First + Column - 1));
               end loop;
            end if;
         end Put;
      begin
         Surface.Fill (' ');
         Surface.Fill_Background ("#101820");
         Surface.Fill_Foreground ("#D6DEE8");
         Put (1, "TUI Template");
         Put
           (3,
            (case State is
               when Tui_Model.Idle   => "Status: Idle",
               when Tui_Model.Active => "Status: Active",
               when Tui_Model.Quit   => ""));
         Put (5, "Space: toggle   Q: quit");

         declare
            Frame : constant Groups.Group := [Groups.Layer (Surface)];
         begin
            Window.Window.Set_Group (Frame);
            Window.Window.Display;
         end;
      end;
   end Display;
end Tui_Renderer;
