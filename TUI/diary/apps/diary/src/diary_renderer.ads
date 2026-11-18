with Diary_Screen_State;

package Diary_Renderer is
   procedure Display (State : Diary_Screen_State.State);
   function Is_Usable return Boolean;
   function Preview_Width return Positive;
end Diary_Renderer;
