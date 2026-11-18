private with Ada.Containers.Vectors;
with Diary_Input;
with Malef.Window;

package Diary_Terminal is
   type Session is limited new Malef.Window.Event_Observer with private;
   procedure Start (Object : aliased in out Session);
   procedure Stop (Object : aliased in out Session);
   procedure Next
     (Object : in out Session; Value : out Diary_Input.Input_Event);
private
   package Input_Vectors is new
     Ada.Containers.Vectors
       (Positive,
        Diary_Input.Input_Event,
        Diary_Input."=");
   protected type Event_Queue is
      procedure Push (Value : Diary_Input.Input_Event);
      entry Pop (Value : out Diary_Input.Input_Event);
   private
      Items : Input_Vectors.Vector;
   end Event_Queue;
   type Session is limited new Malef.Window.Event_Observer with record
      Inbox       : Event_Queue;
      Pending     : Diary_Input.Input_Event;
      Has_Pending : Boolean := False;
      Started     : Boolean := False;
   end record;
end Diary_Terminal;
