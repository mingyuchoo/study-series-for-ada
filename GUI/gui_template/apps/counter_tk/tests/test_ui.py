import sys
import tkinter
import unittest
from pathlib import Path


BACKEND = Path(sys.argv.pop(1)).resolve()
INTERFACE = Path(__file__).resolve().parents[1] / "ui" / "counter.tcl"


class CounterInterfaceTests(unittest.TestCase):
    def setUp(self):
        self.window = tkinter.Tk()
        self.window.withdraw()
        self.window.tk.call("set", "argc", 1)
        self.window.tk.call("set", "argv", (str(BACKEND),))
        self.window.tk.call("source", str(INTERFACE))
        self.window.deiconify()
        self.window.update()
        self.window.tk.call("focus", "-force", ".controls.increment")

    def tearDown(self):
        if self.window.tk.getvar("backend") in self.window.tk.call("chan", "names"):
            self.window.tk.call("close_window")
        else:
            self.window.destroy()

    def test_maximum_disables_increment_and_reset_restores_it(self):
        for _ in range(999):
            self.window.tk.call(".controls.increment", "invoke")

        self.assertEqual(int(self.window.tk.getvar("count")), 999)
        self.assertTrue(self.window.tk.call(".controls.increment", "instate", "disabled"))
        self.assertIn("999", self.window.tk.getvar("status"))
        self.assertEqual(str(self.window.tk.call("focus")), ".controls.reset")

        self.window.tk.call(".controls.increment", "invoke")
        self.assertEqual(int(self.window.tk.getvar("count")), 999)
        self.window.tk.call(".controls.reset", "invoke")

        self.assertEqual(int(self.window.tk.getvar("count")), 0)
        self.assertFalse(self.window.tk.call(".controls.increment", "instate", "disabled"))
        self.assertEqual(str(self.window.tk.call("focus")), ".controls.increment")
        self.assertNotIn("Maximum", self.window.tk.getvar("status"))

    def test_backend_failure_disables_both_actions(self):
        self.window.tk.call("close", self.window.tk.getvar("backend"))
        self.window.tk.call(".controls.increment", "invoke")

        self.assertTrue(self.window.tk.call(".controls.increment", "instate", "disabled"))
        self.assertTrue(self.window.tk.call(".controls.reset", "instate", "disabled"))
        self.assertTrue(self.window.tk.getvar("status"))

    def test_reset_restores_increment_focus_below_maximum(self):
        self.window.tk.call(".controls.increment", "invoke")
        self.window.tk.call("focus", "-force", ".controls.reset")
        self.window.tk.call(".controls.reset", "invoke")

        self.assertEqual(int(self.window.tk.getvar("count")), 0)
        self.assertEqual(str(self.window.tk.call("focus")), ".controls.increment")

    def test_keyboard_shortcuts_increment_and_reset(self):
        self.window.event_generate("<Alt-i>")
        self.assertEqual(int(self.window.tk.getvar("count")), 1)

        self.window.event_generate("<Alt-r>")
        self.assertEqual(int(self.window.tk.getvar("count")), 0)


if __name__ == "__main__":
    unittest.main()
