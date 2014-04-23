Purpose
--------------

**OSCache** is an open-source re-implementation of [`NSCache`](https://developer.apple.com/library/mac/documentation/cocoa/reference/NSCache_Class/Reference/Reference.html) that behaves in a predictable, debuggable way. **OSCache** is an LRU (Least-Recently-Used) cache, meaning that objects will be discarded oldest-first based on the last time they were accessed. **OSCache** will automatically empty itself in the event of a memory warning.

**OSCache** inherits from `NSCache` for convenience (so it can be used more easily as a drop-in replacement), but does not rely on any inherited behaviour.

**OSCache** implements all of the NSCache methods, but does not currently support anything relating to `NSDiscardableContent` and will always return `NO` for `evictsObjectsWithDiscardedContent` regardless of the value you set it to.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 7.1 / Mac OS 10.9 (Xcode 5.1, Apple LLVM compiler 5.1)
* Earliest supported deployment target - iOS 5.0 / Mac OS 10.7
* Earliest compatible deployment target - iOS 4.3 / Mac OS 10.6

*NOTE:* 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

**OSCache** requires ARC. If you wish to use **OSCache** in a non-ARC project, just add the `-fobjc-arc` compiler flag to the `OSCache.m` class. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click `OSCache.m` in the list and type `-fobjc-arc` into the popover.

If you wish to convert your whole project to ARC, comment out the `#error` line in `OSCache.m`, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including `OSCache.m`) are checked.


Installation
--------------

To install **OSCache** into your app, drag the `OSCache.h` and `.m` files into your project. Create and use `OSCache` instances exactly as you would a normal `NSCache`.
