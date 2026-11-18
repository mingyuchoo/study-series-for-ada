with Diary_Controller;
with Diary_Input;
with Diary_Renderer;
with Diary_Screen;
with Diary_Screen_State;
with Diary_Terminal;

package body Diary_App is
   type Terminal_Screen is limited new Diary_Screen.Port with record
      Session : aliased Diary_Terminal.Session;
   end record;
   overriding
   procedure Start (Screen : in out Terminal_Screen);
   overriding
   procedure Display
     (Screen : in out Terminal_Screen; State : Diary_Screen_State.State);
   overriding
   procedure Next
     (Screen : in out Terminal_Screen; Event : out Diary_Input.Input_Event);
   overriding
   function Is_Usable (Screen : Terminal_Screen) return Boolean;
   overriding
   function Preview_Width (Screen : Terminal_Screen) return Positive;

   procedure Start (Screen : in out Terminal_Screen) is
   begin
      Diary_Terminal.Start (Screen.Session);
   end Start;

   procedure Display
     (Screen : in out Terminal_Screen; State : Diary_Screen_State.State)
   is
      pragma Unreferenced (Screen);
   begin
      Diary_Renderer.Display (State);
   end Display;

   procedure Next
     (Screen : in out Terminal_Screen; Event : out Diary_Input.Input_Event) is
   begin
      Diary_Terminal.Next (Screen.Session, Event);
   end Next;

   function Is_Usable (Screen : Terminal_Screen) return Boolean is
      pragma Unreferenced (Screen);
   begin
      return Diary_Renderer.Is_Usable;
   end Is_Usable;

   function Preview_Width (Screen : Terminal_Screen) return Positive is
      pragma Unreferenced (Screen);
   begin
      return Diary_Renderer.Preview_Width;
   end Preview_Width;

   procedure Run
     (Store  : in out Diary_Repositories.Repository'Class;
      Today  : Diary_Dates.Date;
      Keymap : Diary_Keymaps.Kind := Diary_Keymaps.Emacs)
   is
      Screen : Terminal_Screen;
   begin
      begin
         Diary_Controller.Run (Store, Screen, Today, Keymap);
      exception
         when others =>
            Diary_Terminal.Stop (Screen.Session);
            raise;
      end;
      Diary_Terminal.Stop (Screen.Session);
   end Run;
end Diary_App;
