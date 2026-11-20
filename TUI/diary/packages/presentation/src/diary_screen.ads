with Diary_Input;
with Diary_Bindings;
with Diary_Screen_State;

package Diary_Screen is
   type Port is limited interface;
   procedure Start (Screen : in out Port) is abstract;
   procedure Display (Screen : in out Port; State : Diary_Screen_State.State)
   is abstract;
   procedure Next (Screen : in out Port; Event : out Diary_Input.Input_Event)
   is abstract;
   function Is_Usable (Screen : Port) return Boolean is abstract;
   function Preview_Width (Screen : Port) return Positive is abstract;
   procedure Save_Settings
     (Screen : in out Port; Value : Diary_Bindings.Preferences)
   is abstract;
end Diary_Screen;
