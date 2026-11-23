# How ShotCleanup works

[中文](./how-it-works.zh-CN.md) · [Back to README](../README_EN.md)

## The iOS constraint

iOS does not give third-party apps a record of which photos the user just sent, or which app they were sent through. ShotCleanup therefore cannot read the true send result, and creation time alone is not a safe basis for deletion.

Its strategy is: **establish reliable anchors from the current screen, use creation time to recover the rest of the capture batch, then let the user confirm through iOS.**

## Recognition flow

When the shortcut runs:

1. The `Take Screenshot` action captures the current sent-message screen.
2. ShotCleanup loads screenshots created between one second and five minutes before the trigger.
3. The app downsizes and compares image structure and color locally.
4. The bottom-most original screenshot that reliably matches the page becomes the only anchor for this run.
5. Creation times are used to infer the continuous capture batch containing that anchor.
6. iOS shows the final photo count and previews, and the user decides whether to delete them.

ShotCleanup only considers assets marked as screenshots. Neither the captured screen nor Photos-library images are uploaded.

## Time-batch inference

The current version uses these rules:

- only screenshots created between one second and five minutes before the trigger are considered;
- adjacent screenshots no more than 45 seconds apart belong to the same continuous batch;
- one screenshot must reliably match the current page; without a reliable match, no deletion is requested;
- when several batches are visible, only the bottom-most reliable match anchors a batch, so older images higher on the page cannot add another batch;
- an inferred batch of 20 screenshots or fewer is shown in full;
- if an inferred batch contains more than 20 screenshots, only the single anchor screenshot is kept;
- originals that are too similar to distinguish reliably are not used as anchors.

This allows the app to recover a ten-image send even when only two or three images remain visible on screen.

## Why iOS confirmation is still required

A time batch describes continuous capture, not actual sending. If you take ten screenshots but send only eight, the other two may still appear in the inferred candidate set.

ShotCleanup therefore keeps these safety boundaries:

- no reliable screen anchor, no deletion request;
- if an inferred batch contains more than 20 screenshots, only the single anchor screenshot is kept;
- iOS always shows the final count and previews before deletion;
- canceling the system confirmation leaves the photos untouched.

The current approach prioritizes avoiding accidental deletion, but it cannot prove that the candidates exactly match the true send record.

## Current boundaries

- It works best when screenshots are sent soon after capture and cleanup is triggered immediately.
- A screenshot created days ago and resent now is not considered.
- Images that have scrolled off screen, appear very small, or are heavily covered may not provide a reliable anchor.
- Cropping, compression, and page layouts differ between apps, so matching reliability can vary.
- With limited Photos access, only screenshots the user has granted access to can be checked.
