with Counters;

procedure Test_Counter is
   use Counters;
begin
   pragma Assert (Count'First = 0);
   pragma Assert (Count'Last = 999);

   for Value in Count'First .. Count'Last - 1 loop
      pragma Assert (Increment (Value) = Value + 1);
   end loop;

   pragma Assert (Increment (Count'Last) = Count'Last);
end Test_Counter;
