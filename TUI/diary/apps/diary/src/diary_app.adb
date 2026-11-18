with Ada.Characters.Conversions;
with Ada.Exceptions;
with Ada.Strings.Wide_Wide_Unbounded;
with Diary_Editor;
with Diary_Entries;
with Diary_Renderer;
with Diary_Screen_State;
with Diary_Service;
with Diary_Terminal;
with Diary_Text;

package body Diary_App is
   use Ada.Strings.Wide_Wide_Unbounded;
   use Diary_Screen_State;
   use Diary_Terminal;
   use type Diary_Service.Outcome;
   procedure Run
     (Store : in out Diary_Repositories.Repository'Class;
      Today : Diary_Dates.Date)
   is
      State    : Diary_Screen_State.State;
      Terminal : aliased Diary_Terminal.Session;
      Event    : Input_Event;
      Finished : Boolean := False;
      procedure Message (Text : Wide_Wide_String) is
      begin
         State.Message := To_Unbounded_Wide_Wide_String (Text);
      end Message;
      procedure Refresh is
         Result : Diary_Repositories.Entry_Result;
      begin
         State.Scroll := 0;
         State.Read_Failed := True;
         State.Exists := False;
         State.Markers := Diary_Service.Month_Days (Store, State.Selected);
         Result := Diary_Service.Read (Store, State.Selected);
         State.Item := Result.Item;
         State.Exists := Result.Found;
         State.Read_Failed := False;
      end Refresh;
      procedure Begin_Edit is
      begin
         if State.Read_Failed then
            Message
              ("Cannot edit unreadable data. Resolve the file error first.");
            return;
         end if;
         State.Was_Existing := State.Exists;
         Diary_Editor.Load
           (State.Title,
            (if State.Exists
             then To_Wide_Wide_String (State.Item.Title)
             else ""));
         Diary_Editor.Load
           (State.Content,
            (if State.Exists
             then To_Wide_Wide_String (State.Item.Content)
             else ""));
         State.Field := Title_Field;
         State.Mode := Editing;
         Message ("Ctrl+S saves; Esc cancels. Title is required.");
      end Begin_Edit;
      procedure Save is
         Item   : constant Diary_Entries.Entry_Data :=
           (State.Selected,
            To_Unbounded_Wide_Wide_String (Diary_Editor.Text (State.Title)),
            To_Unbounded_Wide_Wide_String (Diary_Editor.Text (State.Content)));
         Result : constant Diary_Service.Outcome :=
           (if State.Was_Existing
            then Diary_Service.Update (Store, Item)
            else Diary_Service.Create (Store, Item));
      begin
         case Result is
            when Diary_Service.Success        =>
               State.Mode := Reading;
               Refresh;
               Message ("Entry saved");

            when Diary_Service.Invalid_Entry  =>
               Message
                 ("Enter a nonblank title; control characters are not allowed.");

            when Diary_Service.Already_Exists =>
               Message ("An entry already exists for this date.");

            when Diary_Service.Not_Found      =>
               Message
                 ("The original entry is missing. Your draft is retained.");
         end case;
      end Save;
      function Dirty return Boolean is
         Original_Title : constant Wide_Wide_String :=
           (if State.Was_Existing
            then To_Wide_Wide_String (State.Item.Title)
            else "");
         Original_Body  : constant Wide_Wide_String :=
           (if State.Was_Existing
            then To_Wide_Wide_String (State.Item.Content)
            else "");
      begin
         return
           Diary_Editor.Text (State.Title) /= Original_Title
           or else Diary_Editor.Text (State.Content) /= Original_Body;
      end Dirty;
      procedure Edit_Buffer
        (Buffer : in out Diary_Editor.Text_Buffer; Is_Title : Boolean) is
      begin
         case Event.Kind is
            when Left_Key      =>
               Diary_Editor.Move (Buffer, Diary_Editor.Backward);

            when Right_Key     =>
               Diary_Editor.Move (Buffer, Diary_Editor.Forward);

            when Up_Key        =>
               Diary_Editor.Move (Buffer, Diary_Editor.Upward);

            when Down_Key      =>
               Diary_Editor.Move (Buffer, Diary_Editor.Downward);

            when Character_Key =>
               case Wide_Wide_Character'Pos (Event.Letter) is
                  when 1                             =>
                     Diary_Editor.Move (Buffer, Diary_Editor.Line_Start);

                  when 5                             =>
                     Diary_Editor.Move (Buffer, Diary_Editor.Line_End);

                  when 8 | 127                       =>
                     Diary_Editor.Backspace (Buffer);

                  when 10 | 13                       =>
                     if Is_Title then
                        State.Field := Body_Field;
                     else
                        Diary_Editor.Insert
                          (Buffer, Wide_Wide_Character'Val (10));
                     end if;

                  when 32 .. 126 | 160 .. 16#10FFFF# =>
                     Diary_Editor.Insert (Buffer, Event.Letter);

                  when others                        =>
                     null;
               end case;

            when others        =>
               null;
         end case;
      end Edit_Buffer;
      procedure Handle_Editor is
      begin
         if Event.Kind = Escape_Key then
            State.Mode := (if Dirty then Confirm_Discard else Reading);
         elsif Event.Kind = Character_Key
           and then Wide_Wide_Character'Pos (Event.Letter) = 19
         then
            Save;
         elsif Event.Kind = Character_Key
           and then Wide_Wide_Character'Pos (Event.Letter) = 9
         then
            State.Field :=
              (if State.Field = Title_Field then Body_Field else Title_Field);
         elsif State.Field = Title_Field then
            Edit_Buffer (State.Title, True);
         else
            Edit_Buffer (State.Content, False);
         end if;
      end Handle_Editor;
      procedure Navigate (Day_Delta : Integer := 0; Month_Delta : Integer := 0)
      is
      begin
         State.Selected :=
           Diary_Dates.Shift_Month
             (Diary_Dates.Shift_Days (State.Selected, Day_Delta), Month_Delta);
         Refresh;
         Message ("");
      end Navigate;
      procedure Handle_Reading is
      begin
         case Event.Kind is
            when Left_Key      =>
               Navigate (Day_Delta => -1);

            when Right_Key     =>
               Navigate (Day_Delta => 1);

            when Up_Key        =>
               Navigate (Day_Delta => -7);

            when Down_Key      =>
               Navigate (Day_Delta => 7);

            when Character_Key =>
               case Event.Letter is
                  when 'q' | 'Q'                    =>
                     Finished := True;

                  when '['                          =>
                     Navigate (Month_Delta => -1);

                  when ']'                          =>
                     Navigate (Month_Delta => 1);

                  when 't' | 'T'                    =>
                     State.Selected := Today;
                     Refresh;
                     Message ("");

                  when 'n' | 'N'                    =>
                     if State.Exists then
                        Message
                          ("This date already has an entry. Press E to edit.");
                     else
                        Begin_Edit;
                     end if;

                  when 'e'
                     | 'E'
                     | Wide_Wide_Character'Val (10)
                     | Wide_Wide_Character'Val (13) =>
                     Begin_Edit;

                  when 'd' | 'D'                    =>
                     if State.Exists or else State.Read_Failed then
                        State.Mode := Confirm_Delete;
                     else
                        Message ("There is no entry to delete.");
                     end if;

                  when 'j' | 'J'                    =>
                     if State.Exists
                       and then State.Scroll
                                < Diary_Text.Position_At
                                    (To_Wide_Wide_String (State.Item.Content),
                                     Length (State.Item.Content),
                                     Positive'Max
                                       (1, Diary_Renderer.Preview_Width - 2))
                                    .Row
                     then
                        State.Scroll := State.Scroll + 1;
                     end if;

                  when 'k' | 'K'                    =>
                     State.Scroll := Natural'Max (1, State.Scroll) - 1;

                  when others                       =>
                     null;
               end case;

            when others        =>
               null;
         end case;
      end Handle_Reading;
      procedure Handle_Confirmation is
         Result : Diary_Service.Outcome;
      begin
         if Event.Kind = Escape_Key
           or else (Event.Kind = Character_Key
                    and then Event.Letter in 'n' | 'N')
         then
            State.Mode :=
              (if State.Mode = Confirm_Discard then Editing else Reading);
         elsif Event.Kind = Character_Key and then Event.Letter in 'y' | 'Y'
         then
            if State.Mode = Confirm_Delete then
               Result := Diary_Service.Delete (Store, State.Selected);
               State.Mode := Reading;
               Refresh;
               Message
                 ((if Result = Diary_Service.Success
                   then "Entry deleted"
                   else "Entry no longer exists"));
            else
               State.Mode := Reading;
               Message ("Changes discarded");
            end if;
         end if;
      end Handle_Confirmation;
   begin
      State.Selected := Today;
      State.Today := Today;
      begin
         Refresh;
      exception
         when Error : Diary_Repositories.Storage_Error =>
            Message
              (Ada.Characters.Conversions.To_Wide_Wide_String
                 (Ada.Exceptions.Exception_Message (Error)));
      end;
      Diary_Terminal.Start (Terminal);
      loop
         Diary_Renderer.Display (State);
         Diary_Terminal.Next (Terminal, Event);
         begin
            if Diary_Renderer.Is_Usable then
               case State.Mode is
                  when Reading                          =>
                     Handle_Reading;

                  when Editing                          =>
                     Handle_Editor;

                  when Confirm_Delete | Confirm_Discard =>
                     Handle_Confirmation;
               end case;
            elsif State.Mode = Reading
              and then Event.Kind = Character_Key
              and then Event.Letter in 'q' | 'Q'
            then
               Finished := True;
            end if;
         exception
            when Error : Diary_Repositories.Storage_Error =>
               Message
                 (Ada.Characters.Conversions.To_Wide_Wide_String
                    (Ada.Exceptions.Exception_Message (Error)));
         end;
         exit when Finished;
      end loop;
      Diary_Terminal.Stop (Terminal);
   exception
      when others =>
         Diary_Terminal.Stop (Terminal);
         raise;
   end Run;
end Diary_App;
