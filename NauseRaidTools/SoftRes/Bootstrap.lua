local _, A = ...
-- One addon namespace, with isolated loot-system state and the existing public
-- alias retained for internal integrations and diagnostic macros.
A.SoftRes = {base=A,version=A.version,bundled=true}
NauseSoftReserve = A.SoftRes
