private with Ada.Containers.Vectors;
with Malef.Window;

package Diary_Terminal is
   type Key_Kind is (Character_Key, Left_Key, Right_Key, Up_Key, Down_Key, Escape_Key, Resize_Key, Unknown_Key);
   type Input_Event is record
      Kind : Key_Kind := Unknown_Key;
      Letter : Wide_Wide_Character := ' ';
   end record;
   type Session is limited new Malef.Window.Event_Observer with private;
   procedure Start (Object : aliased in out Session);
   procedure Stop (Object : aliased in out Session);
   procedure Next (Object : in out Session; Value : out Input_Event);
private
   package Input_Vectors is new Ada.Containers.Vectors (Positive, Input_Event);
   protected type Event_Queue is
      procedure Push (Value : Input_Event);
      entry Pop (Value : out Input_Event);
   private
      Items : Input_Vectors.Vector;
   end Event_Queue;
   type Session is limited new Malef.Window.Event_Observer with record
      Inbox : Event_Queue;
      Pending : Input_Event;
      Has_Pending : Boolean := False;
      Started : Boolean := False;
   end record;
end Diary_Terminal;
