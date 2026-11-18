with Counter_Actions;

procedure Test_Counter is
   use Counter_Actions;
   use type Count;

   Value : Count := Initial_Count;
begin
   pragma Assert (Value = 0);

   for Expected in 1 .. Count'Last loop
      Value := Apply (Value, Increment);
      pragma Assert (Value = Expected);
   end loop;

   pragma Assert (Apply (Value, Increment) = Value);
   pragma Assert (Apply (Value, Reset) = 0);
   pragma Assert (Apply (0, Reset) = 0);
   pragma Assert (Apply (Apply (42, Reset), Increment) = 1);
end Test_Counter;
