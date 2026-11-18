package Diary_Keymaps is
   type Kind is (Emacs, Helix);
   function Label (Value : Kind) return Wide_Wide_String
   is (case Value is
         when Emacs => "Emacs",
         when Helix => "Helix");
end Diary_Keymaps;
