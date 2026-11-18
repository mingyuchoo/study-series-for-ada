with Malef.System;
with Malef.Events;

package body Diary_Terminal is
   protected body Event_Queue is
      procedure Push (Value : Input_Event) is
      begin
         Items.Append (Value);
      end Push;
      entry Pop (Value : out Input_Event) when not Items.Is_Empty is
      begin
         Value := Items.First_Element;
         Items.Delete_First;
      end Pop;
   end Event_Queue;
   protected Dispatcher is
      procedure Receive (Observer : aliased in out Malef.Window.Event_Observer'Class; Event : Malef.Events.Event_Type);
   end Dispatcher;
   protected body Dispatcher is
      procedure Receive (Observer : aliased in out Malef.Window.Event_Observer'Class; Event : Malef.Events.Event_Type) is
         Value : Input_Event;
      begin
         case Event.Name is
            when Malef.Events.Resize_Event => Value.Kind := Resize_Key;
            when Malef.Events.Keyboard_Event =>
               case Event.Key is
                  when Malef.Events.Key_Left => Value.Kind := Left_Key;
                  when Malef.Events.Key_Right => Value.Kind := Right_Key;
                  when Malef.Events.Key_Up => Value.Kind := Up_Key;
                  when Malef.Events.Key_Down => Value.Kind := Down_Key;
                  when Malef.Events.Key_Unknown => Value.Kind := Escape_Key;
                  when others => Value := (Character_Key, Wide_Wide_Character (Event.Key));
               end case;
            when others => return;
         end case;
         Session (Observer).Inbox.Push (Value);
      end Receive;
   end Dispatcher;
   procedure Start (Object : aliased in out Session) is
   begin
      Malef.Window.Callbacks.Register (Malef.Events.Keyboard_Event, Object'Unchecked_Access, Dispatcher.Receive'Access);
      Malef.Window.Callbacks.Register (Malef.Events.Resize_Event, Object'Unchecked_Access, Dispatcher.Receive'Access);
      Object.Started := True;
      Malef.System.Initialize;
   end Start;
   procedure Stop (Object : aliased in out Session) is
   begin
      if Object.Started then
         Malef.Window.Callbacks.Unregister (Malef.Events.Keyboard_Event, Object'Unchecked_Access);
         Malef.Window.Callbacks.Unregister (Malef.Events.Resize_Event, Object'Unchecked_Access);
         Malef.System.Finalize;
         Object.Started := False;
      end if;
   end Stop;
   procedure Next (Object : in out Session; Value : out Input_Event) is
      Following : Input_Event;
      procedure Timed_Read (Result : out Input_Event; Available : out Boolean) is
      begin
         Available := True;
         select
            Object.Inbox.Pop (Result);
         or
            delay 0.06;
            Available := False;
         end select;
      end Timed_Read;
      Available : Boolean;
      Parameterized : Boolean := False;
   begin
      if Object.Has_Pending then
         Value := Object.Pending;
         Object.Has_Pending := False;
      else
         Object.Inbox.Pop (Value);
      end if;
      if Value.Kind /= Escape_Key then
         return;
      end if;
      Timed_Read (Following, Available);
      if not Available then
         return;
      elsif Following.Kind /= Character_Key or else Following.Letter not in '[' | 'O' then
         Object.Pending := Following;
         Object.Has_Pending := True;
         return;
      end if;
      Value.Kind := Unknown_Key;
      loop
         Timed_Read (Following, Available);
         if not Available then
            return;
         elsif Following.Kind /= Character_Key then
            Object.Pending := Following;
            Object.Has_Pending := True;
            return;
         elsif Following.Letter in ' ' .. '?' then
            Parameterized := True;
         elsif Following.Letter in '@' .. '~' then
            if not Parameterized then
               case Following.Letter is
                  when 'A' => Value.Kind := Up_Key;
                  when 'B' => Value.Kind := Down_Key;
                  when 'C' => Value.Kind := Right_Key;
                  when 'D' => Value.Kind := Left_Key;
                  when 'H' => Value := (Character_Key, Wide_Wide_Character'Val (1));
                  when 'F' => Value := (Character_Key, Wide_Wide_Character'Val (5));
                  when others => null;
               end case;
            end if;
            return;
         else
            return;
         end if;
      end loop;
   end Next;
end Diary_Terminal;
