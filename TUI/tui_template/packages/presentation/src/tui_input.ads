package Tui_Input
  with Pure
is
   type Key_Kind is
     (Character_Key,
      Left_Key,
      Right_Key,
      Up_Key,
      Down_Key,
      Home_Key,
      End_Key,
      Escape_Key,
      Meta_Key,
      Resize_Key,
      Unknown_Key);
   type Input_Event is record
      Kind   : Key_Kind := Unknown_Key;
      Letter : Wide_Wide_Character := ' ';
   end record;
end Tui_Input;
