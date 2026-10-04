# Local patches to vendored addons

`client-patch/addon/TransmogAzerothCore/` is third-party
(LleguitoWoW/Transmog-Visual-Azerothcore) and is gitignored, so anything fixed
in it lives only on this disk and is lost the moment the addon is re-downloaded.
These patches exist so that cannot happen quietly.

Apply after refreshing the addon:

    cd client-patch/addon/TransmogAzerothCore
    patch -p1 --forward < ../../addon-patches/transmog-queryitem-throttle.patch

`--forward` so a patch that is already in fails rather than reversing itself.
Each one is also worth reporting upstream; they are bugs in the addon rather
than anything this realm does differently.

## transmog-queryitem-throttle.patch

`dummy_OnUpdate` adds the frame delta to `self.elapsed` and runs its sweep once
that reaches `PERIOD`, but never cleared the accumulator - so the comparison was
true on every frame once it had been true once. `PERIOD` threw nothing away and
the sweep ran at the frame rate instead of ten times a second, calling
`GetItemInfo` for every pending item while a batch of uncached ones worked
through its 180 second `QUERY_TIME`. The frame is parented to `UIParent` with no
visibility gate, so it ran with every window closed.

The handler timeouts also had to move from counting down by one frame's delta to
counting down by the accumulated interval. That part is not cosmetic: the body
used to run every frame, which made charging a single frame roughly correct, and
fixing the throttle without it would have stretched 180 seconds to about half an
hour.

Found while looking for the cause of a client freeze with no windows open. It is
**not** established as that cause - the sweep is self-limiting after
`QUERY_TIME`, and the freeze in question outlasted that and never recovered.
