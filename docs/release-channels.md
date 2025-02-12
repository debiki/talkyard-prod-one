
Release Channels
======================================================================

Later, you can choose between:
1. Getting new features and bug fixes more often — the `regular` release branch.
2. Getting only important bug fixes — the `lts` (Long Term Stable) branch.

You choose this by editing `/opt/talkyard-v1/.env`
and setting `RELEASE_BRANCH=regular` or `...=lts`.

Currently only the `regular` branch exists.
It's the default, so you don't need to do anything.

(This is inspired by Kubernetes' release channels:
https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels)

