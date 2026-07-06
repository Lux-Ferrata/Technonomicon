{ pkgs }:
let
  python = pkgs.python3.withPackages (ps: [ ps.requests ps.tkinter ]);

  script = pkgs.writeText "tomatych.py" ''
    try:
        import Tkinter as tk
    except ImportError:
        import tkinter as tk
    import time, datetime, os, requests

    API_TOKEN = os.environ.get("HABITICA_API_TOKEN", "")
    USER_ID   = os.environ.get("HABITICA_USER_ID", "")
    TASK_ID   = os.environ.get("HABITICA_TASK_ID", "")

    def score(direction):
        if not (API_TOKEN and USER_ID and TASK_ID):
            return
        requests.post(
            "https://habitica.com/api/v3/tasks/" + TASK_ID + "/score/" + direction,
            headers={
                "x-api-key":  API_TOKEN,
                "x-api-user": USER_ID,
                "x-client":   USER_ID + "-tomatych-nixos",
            },
        )

    class App():
        def __init__(self):
            self.root = tk.Tk()
            self.root.wm_attributes("-topmost", 1)
            self.root.tk.call('wm', 'iconphoto', self.root._w, tk.PhotoImage(data="R0lGODlhIAAgAOMIAAAAAHkAAJcDALUhBgBlANM/JAChAPFdQv///////////////////////////////yH+EUNyZWF0ZWQgd2l0aCBHSU1QACH5BAEKAAgALAAAAAAgACAAAASwEMlJq704622BB0ZofKDIUaQ4fuo5pSIcupK8eu1GkkM/EEDC7oMZeny/oBFQNCKDQmNz+FRKX5+D9lDoFlRIsG+55XrFPfSAvPV+RWH42Fh2q9VLN3LPHwj+AnlefYR+gIJdhX2AgUZ6inuMS5CGjH8BmAGTkJaAmZpOnJ0Cn5uKo6SZJCgfSKilRBc8Pq+qsR2ttKOwHlMArru2vTpLVy7FxifIQzQIyzvN0dLTEhEAOw=="))
            self.label = tk.Label(font=("Helvetica Neue", 44))
            self.label.pack()
            self.buttons = tk.Frame(self.root)
            self.buttons.pack()
            tk.Button(self.buttons, text="Start",  command=lambda: self.start()).pack(side=tk.LEFT)
            tk.Button(self.buttons, text="Cancel", command=lambda: self.cancel()).pack(side=tk.LEFT)
            self.end     = time.time()
            self.started = False
            self.update_clock()
            self.root.mainloop()

        def start(self):
            self.started = True
            self.end = time.time() + datetime.timedelta(minutes=25).total_seconds()

        def cancel(self):
            self.started = False
            self.end = time.time()
            score("down")

        def complete(self):
            self.started = False
            score("up")

        def update_clock(self):
            delta = self.end - time.time()
            if delta < 0:
                self.label.configure(text="00:00", bg="#d9d9d9")
                self.root.wm_title("Pomodoro")
                if self.started:
                    self.complete()
            else:
                time_left = datetime.datetime.fromtimestamp(delta).strftime("%M:%S")
                self.root.wm_title("(%s) Pomodoro" % time_left)
                self.label.configure(text=time_left, bg="#ca1616")
            self.root.after(1000, self.update_clock)

    app = App()
  '';
in
pkgs.writeShellScriptBin "tomatych" ''
  export HABITICA_API_TOKEN="$(cat /run/secrets/habitica-api-token 2>/dev/null || true)"
  export HABITICA_USER_ID="$(cat /run/secrets/habitica-user-id 2>/dev/null || true)"
  export HABITICA_TASK_ID="$(cat /run/secrets/habitica-task-id 2>/dev/null || true)"
  exec ${python}/bin/python3 ${script}
''
