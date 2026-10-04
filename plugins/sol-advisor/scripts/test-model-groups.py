#!/usr/bin/env python3
"""Independent expectations; fixtures do not certify host discovery or model execution."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
PLUGIN = SCRIPTS.parent


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


M = load("model_group", "model-group.py")
B = load("backup_roles", "backup-roles.py")
# Independently authored expectations; never derive these from GROUPS.
EXPECTED = {
    "legacy": [("sol_advisor_luna_implementer", "gpt-5.6-luna", "max"),
               ("sol_advisor_terra_implementer", "gpt-5.6-terra", "high"),
               ("sol_advisor_sol_reviewer", "gpt-5.6-sol", "high")],
    "current": [("sol_advisor_current_routine_implementer", "gpt-6-luna", "max"),
                ("sol_advisor_current_complex_implementer", "gpt-6.1-sol", "high"),
                ("sol_advisor_current_reviewer", "gpt-6.1-sol", "high")],
}


def shell_path(path):
    value = str(path.absolute())
    if os.name == "nt":
        return "/" + value[0].lower() + value[2:].replace("\\", "/")
    return value


class Groups(unittest.TestCase):
    def test_all_routes_both_groups(self):
        for model, group in (("gpt-5.6-sol", "legacy"), ("gpt-6.1-sol", "current")):
            for route, impl, indexes in (("solo", None, []), ("delegate", "routine", [0]),
                    ("delegate", "complex", [1]), ("audit", None, [2]),
                    ("full", "routine", [0, 2]), ("full", "complex", [1, 2])):
                value = M.plan(model, "high", route, impl)
                self.assertEqual(value["group"], group)
                self.assertEqual([(r["role"], r["model"], r["effort"]) for r in value["roles"]],
                                 [EXPECTED[group][i] for i in indexes])

    def test_exact_entry_and_effort_refusal(self):
        for model in ("gpt-6-sol", "gpt-6-astra", "gpt-6-astra-latest", "gpt-6.1-sol-latest", "unknown", ""):
            with self.assertRaises(ValueError): M.plan(model, "high", "solo")
        for model in ("gpt-5.6-sol", "gpt-6.1-sol"):
            for effort in ("xhigh", "max", "medium", "High", "", None):
                with self.assertRaises(ValueError): M.plan(model, effort, "solo")
        for route, impl in (("new", None), ("solo", "routine"), ("audit", "complex"),
                            ("delegate", None), ("full", "terra")):
            with self.assertRaises(ValueError): M.plan("gpt-6.1-sol", "high", route, impl)

    def test_effective_primary_and_confirmation(self):
        self.assertEqual(M.confirm_primary({"model": "gpt-6.1-sol", "effort": "high"}, {}),
                         ("gpt-6.1-sol", "high", "runtime"))
        self.assertEqual(M.confirm_primary({}, {"model": "gpt-6.1-sol", "effort": "high"}),
                         ("gpt-6.1-sol", "high", "user-confirmation"))
        self.assertEqual(M.confirm_primary({"model": "gpt-6.1-sol"}, {"effort": "high"})[2], "user-confirmation")
        with self.assertRaises(ValueError): M.confirm_primary({}, {})
        with self.assertRaises(ValueError): M.confirm_primary({"model": "gpt-6-sol"}, {"model": "gpt-6.1-sol", "effort": "high"})
        # Historical root turns are excluded from this effective-turn evidence API.
        history = [{"model": "gpt-5.6-sol", "effort": "high"}, {"model": "gpt-6.1-sol", "effort": "high"}]
        self.assertEqual(M.confirm_primary(history[-1], {})[0], "gpt-6.1-sol")

    def test_new_unit_and_active_unit_change(self):
        old = dict(M.plan("gpt-5.6-sol", "high", "solo"), thread_id="same-root", unit_id="old", config_fingerprint="a")
        new = dict(M.plan("gpt-6.1-sol", "high", "solo"), thread_id="same-root", unit_id="new", config_fingerprint="b")
        self.assertFalse(M.check_unit(old, new, False)["role_checks_cached"])
        self.assertEqual(M.check_unit(old, new, False)["thread_id"], "same-root")
        with self.assertRaises(ValueError): M.check_unit(old, new, True)
        same = dict(new)
        self.assertFalse(M.check_unit(new, same, True)["role_checks_cached"])
        for field in ("primary_model", "primary_effort", "config_fingerprint", "thread_id", "unit_id", "group"):
            changed = dict(new); changed[field] = "different"
            with self.assertRaises(ValueError): M.check_unit(new, changed, True)

    def test_discovery_scope_and_shadowing(self):
        routine = M.plan("gpt-6.1-sol", "high", "delegate", "routine")["roles"]
        M.check_discovery([], [])  # solo has no auxiliary dependency
        M.check_discovery(routine, routine)  # no reviewer/legacy dependency
        for discovered in ([], [*routine, *routine], [{**routine[0], "model": "gpt-5.6-luna"}]):
            with self.assertRaises(ValueError): M.check_discovery(routine, discovered)

    def test_runtime_pins_parent_and_isolation(self):
        for expected in M.plan("gpt-6.1-sol", "high", "full", "complex")["roles"]:
            record = dict(agent_role=expected["role"], model=expected["model"], effort=expected["effort"],
                          thread_id="child", parent_thread_id="root", cwd="isolated", sandbox_policy_type="read-only",
                          permission_profile_type="managed")
            M.check_runtime(expected, record, "root", "isolated")
            for field in ("agent_role", "model", "effort", "parent_thread_id", "cwd", "thread_id"):
                changed = dict(record); changed[field] = ""
                with self.assertRaises(ValueError): M.check_runtime(expected, changed, "root", "isolated")
            changed = dict(record, model="gpt-5.6-terra")
            with self.assertRaises(ValueError): M.check_runtime(expected, changed, "root", "isolated")
        self.assertEqual(M.check_isolation(record), "enforced-read-only")
        with self.assertRaises(ValueError): M.check_isolation({})
        broad = dict(record, sandbox_policy_type="workspace-write")
        with self.assertRaises(ValueError): M.check_isolation(broad)
        with self.assertRaises(ValueError): M.check_isolation(broad, hard_required=True, unchanged=True)
        self.assertIn("broader", M.check_isolation(broad, unchanged=True))

    def test_mapping_tamper_is_detected_by_independent_expectation(self):
        original = M.GROUPS["gpt-6.1-sol", "high"]
        try:
            roles = dict(original[1]); roles["complex"] = EXPECTED["legacy"][1]
            M.GROUPS["gpt-6.1-sol", "high"] = ("current", roles)
            actual = M.plan("gpt-6.1-sol", "high", "delegate", "complex")["roles"][0]
            self.assertNotEqual((actual["role"], actual["model"], actual["effort"]), EXPECTED["current"][1])
        finally:
            M.GROUPS["gpt-6.1-sol", "high"] = original


class Installation(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sol-advisor-groups-")
        self.root = Path(self.tmp.name)
        self.target = self.root / "agents"; self.target.mkdir()

    def tearDown(self):
        self.tmp.cleanup()

    def run_installer(self, *args, ok=True, env=None, installer=None):
        result = subprocess.run(["sh", shell_path(installer or SCRIPTS / "install-agents.sh"),
                                 "--target-dir", shell_path(self.target), *args],
                                capture_output=True, text=True, env=env)
        if ok: self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else: self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def state(self):
        return {p.name: p.read_bytes() for p in self.target.iterdir() if p.is_file()}

    def test_install_both_and_current_independence(self):
        self.run_installer()  # retained old default
        old = self.state()
        self.assertEqual(set(old), set(B.FILES["legacy"]))
        self.run_installer("--group", "current")
        self.assertEqual({name:self.state()[name] for name in old}, old)
        self.assertEqual(set(self.state()), set(B.FILES["legacy"] + B.FILES["current"]))
        before=self.state(); self.run_installer("--group", "all"); self.assertEqual(self.state(),before)
        (self.target/B.FILES["legacy"][1]).write_text("legacy conflict")
        self.run_installer("--group", "current", "--check")
        (self.target/B.FILES["current"][2]).write_text("unused reviewer conflict")
        self.run_installer("--group", "current", "--check-role", "routine")
        self.run_installer("--group", "current", "--check-role", "sol_advisor_current_complex_implementer")
        self.run_installer("--group", "all", "--check", ok=False)

    def test_invalid_parameters_and_conflict_before_writes(self):
        for args in (("--group", "bad"), ("--group",), ("--group", "current", "--check-role", "terra"),
                     ("--group", "legacy", "--check-role", "routine"), ("--check-role",), ("--check-role", "unknown")):
            before=self.state(); self.run_installer(*args,ok=False); self.assertEqual(self.state(),before)
        path=self.target/B.FILES["current"][2]; path.write_text("modified")
        before=self.state(); self.run_installer("--group","current",ok=False); self.assertEqual(self.state(),before)
        path.unlink(); path.mkdir()
        self.run_installer("--group","current",ok=False)
        self.assertEqual(set(self.target.iterdir()),{path})

    def test_unused_template_is_not_checked(self):
        self.run_installer("--group", "current")
        copy=self.root/'plugin'; shutil.copytree(PLUGIN,copy)
        (copy/'agents'/B.FILES['current'][2]).unlink()
        (copy/'agents'/B.FILES['legacy'][0]).write_text('unused legacy')
        self.run_installer("--group","current","--check-role","routine",installer=copy/'scripts/install-agents.sh')
        self.run_installer("--group","current","--check-role","reviewer",ok=False,installer=copy/'scripts/install-agents.sh')

    def test_current_symlink_and_ancestor_refusal(self):
        destination=self.target/B.FILES['current'][0]
        source=PLUGIN/'agents'/B.FILES['current'][0]
        subprocess.run(['sh','-c','ln -s "$1" "$2"','probe',shell_path(source),shell_path(destination)],check=True)
        observed=subprocess.run(['sh','-c','test -L "$1"','probe',shell_path(destination)])
        self.assertEqual(observed.returncode,0,'test host must create a real shell-observable symlink')
        self.run_installer('--group','current',ok=False)
        self.assertFalse((self.target/B.FILES['current'][1]).exists())
        linked=self.root/'linked'
        subprocess.run(['sh','-c','ln -s "$1" "$2"','probe',shell_path(self.target),shell_path(linked)],check=True)
        original=self.target; self.target=linked/'nested'
        try: self.run_installer('--group','current',ok=False)
        finally: self.target=original
        self.assertFalse((self.target/'nested').exists())

    def test_backup_restore_and_concurrent_modification_refusal(self):
        self.run_installer()
        (self.target/'user-note.txt').write_text('unrelated user file')
        before=self.state(); backup=self.root/'backup'
        B.snapshot(self.target,backup,'all')
        self.run_installer('--group','all')
        installed=self.state()
        changed=self.target/B.FILES['current'][1]; changed.write_text('user edit')
        conflict=self.state()
        with self.assertRaises(ValueError): B.restore(self.target,backup)
        self.assertEqual(self.state(),conflict)
        changed.write_bytes(installed[changed.name])
        B.restore(self.target,backup); self.assertEqual(self.state(),before)
        B.restore(self.target,backup); self.assertEqual(self.state(),before)
        with self.assertRaises(ValueError): B.snapshot(self.target,backup,'all')

    def test_backup_tamper_refusal(self):
        backup=self.root/'backup'
        B.snapshot(self.target,backup,'current')
        self.run_installer('--group','current')
        before=self.state()
        receipt=backup/'roles.json'; data=json.loads(receipt.read_text())
        data['files'][B.FILES['current'][0]]['before']='dGFtcGVy'
        receipt.write_text(json.dumps(data))
        with self.assertRaises(ValueError): B.restore(self.target,backup)
        self.assertEqual(self.state(),before)

    def test_later_write_failure_is_reported_without_claiming_rollback(self):
        tools=self.root/'tools'; tools.mkdir()
        real_ln=shutil.which('ln')
        self.assertIsNotNone(real_ln)
        wrapper=tools/'ln'
        wrapper.write_text('#!/bin/sh\ncase "$2" in *current-reviewer.toml) exit 77 ;; esac\nexec "'+shell_path(Path(real_ln))+'" "$@"\n',encoding='utf-8')
        wrapper.chmod(0o755)
        env=dict(os.environ); env['PATH']=str(tools)+os.pathsep+env['PATH']
        result=self.run_installer('--group','current',ok=False,env=env)
        self.assertIn('not rolled back',result.stderr)
        self.assertTrue((self.target/B.FILES['current'][0]).exists())
        self.assertTrue((self.target/B.FILES['current'][1]).exists())
        self.assertFalse((self.target/B.FILES['current'][2]).exists())

    def test_post_write_corruption_is_rejected(self):
        tools=self.root/'tools'; tools.mkdir(); real_ln=shutil.which('ln')
        wrapper=tools/'ln'
        wrapper.write_text('#!/bin/sh\n"'+shell_path(Path(real_ln))+'" "$@" || exit $?\ncase "$2" in *current-reviewer.toml) printf corrupt >> "$2" ;; esac\n',encoding='utf-8')
        wrapper.chmod(0o755)
        env=dict(os.environ); env['PATH']=str(tools)+os.pathsep+env['PATH']
        result=self.run_installer('--group','current',ok=False,env=env)
        self.assertIn('post-install exactness',result.stderr)


class RuntimeInspector(unittest.TestCase):
    def test_current_roles_and_safe_negative_fixtures(self):
        with tempfile.TemporaryDirectory(prefix='sol-advisor-runtime-') as temp:
            sessions=Path(temp)
            thread_id='11111111-1111-7111-8111-111111111111'
            rollout=sessions/('rollout-fixture-'+thread_id+'.jsonl')
            def inspect(rows, ok):
                rollout.write_text('\n'.join(json.dumps(row) for row in rows)+'\n',encoding='utf-8')
                result=subprocess.run(['sh',shell_path(SCRIPTS/'inspect-agent-runtime.sh'),
                    '--sessions-dir',shell_path(sessions),thread_id],capture_output=True,text=True)
                self.assertEqual(result.returncode==0,ok,result.stderr)
                self.assertNotIn('DO_NOT_LEAK',result.stdout+result.stderr)
                if ok:
                    value=json.loads(result.stdout)
                    self.assertEqual(set(value),{'thread_id','parent_thread_id','agent_role','agent_path',
                        'model_provider','model','effort','sandbox_policy_type','permission_profile_type','cwd'})
                    return value
            for role,model,effort in EXPECTED['current']:
                meta={'type':'session_meta','payload':{'id':thread_id,'agent_role':role,
                    'parent_thread_id':'00000000-0000-7000-8000-000000000000','cwd':'/isolated'}}
                turn={'type':'turn_context','payload':{'model':model,'effort':effort,'cwd':'/isolated',
                    'sandbox_policy':{'type':'read-only'},'permission_profile':{'type':'managed'}}}
                secret={'type':'response_item','payload':{'prompt':'DO_NOT_LEAK_PROMPT','token':'DO_NOT_LEAK_TOKEN'}}
                rows=[meta,turn,secret]
                value=inspect(rows,True)
                self.assertEqual((value['agent_role'],value['model'],value['effort']),(role,model,effort))
                inspect([meta,secret],False)
                inspect([meta,{**turn,'payload':{**turn['payload'],'model':None}},secret],False)
                inspect([meta,turn,{**turn,'payload':{**turn['payload'],'model':'gpt-5.6-sol'}},secret],False)
                inspect([meta,turn,{**turn,'payload':{**turn['payload'],'effort':'xhigh'}},secret],False)
                inspect([meta,meta,turn,secret],False)
            duplicate=sessions/('rollout-duplicate-'+thread_id+'.jsonl')
            duplicate.write_bytes(rollout.read_bytes())
            inspect(rows,False)


if __name__ == '__main__':
    unittest.main(verbosity=2)
