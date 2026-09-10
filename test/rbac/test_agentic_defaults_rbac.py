"""Check the permissions used by the operator's curated-defaults tasks.

Run with `python3 -m unittest discover -s test/rbac -v`.
Requires PyYAML and Helm; set HELM to override the Helm executable.
"""

import os
from pathlib import Path
import subprocess
import unittest

import yaml


ROOT = Path(__file__).resolve().parents[2]
RESOURCES = ("agents", "agentworkflows", "skillcards", "skillcollections")
VERBS = ("get", "list", "watch", "create", "update", "patch", "delete")


class AgenticDefaultsRBACTest(unittest.TestCase):
    def assert_curated_permissions(self, rules):
        for resource in RESOURCES:
            for verb in VERBS:
                with self.subTest(resource=resource, verb=verb):
                    self.assertTrue(
                        any(
                            "konveyor.io" in rule.get("apiGroups", [])
                            and resource in rule.get("resources", [])
                            and verb in rule.get("verbs", [])
                            and not rule.get("resourceNames")
                            for rule in rules
                        ),
                        f"tackle-operator needs {verb} on {resource}.konveyor.io",
                    )

    def test_helm_grants_namespaced_permissions_to_operator(self):
        rendered = subprocess.check_output(
            [os.environ.get("HELM", "helm"), "template", "test", str(ROOT / "helm")],
            text=True,
        )
        objects = list(yaml.safe_load_all(rendered))
        bound_roles = {
            obj["roleRef"]["name"]
            for obj in objects
            if obj and obj["kind"] == "RoleBinding"
            and obj["roleRef"]["kind"] == "Role"
            and any(
                subject["kind"] == "ServiceAccount"
                and subject["name"] == "tackle-operator"
                for subject in obj["subjects"]
            )
        }
        rules = [
            rule
            for obj in objects
            if obj and obj["kind"] == "Role" and obj["metadata"]["name"] in bound_roles
            for rule in obj["rules"]
        ]
        self.assert_curated_permissions(rules)

    def test_bundle_grants_namespaced_permissions_to_operator(self):
        csv = yaml.safe_load(
            (ROOT / "bundle/manifests/konveyor-operator.clusterserviceversion.yaml").read_text()
        )
        rules = [
            rule
            for permission in csv["spec"]["install"]["spec"]["permissions"]
            if permission["serviceAccountName"] == "tackle-operator"
            for rule in permission["rules"]
        ]
        self.assert_curated_permissions(rules)


if __name__ == "__main__":
    unittest.main()
