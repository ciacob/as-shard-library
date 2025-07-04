package com.github.ciacob.asshardlibrary {
    import flash.utils.ByteArray;

    /**
     * Simple data structure.
     * Can be used as such, or chained to build complex data structures.
     * Both hierarchical and flat data structures can be obtained.
     * Built with subclassing in mind.
     *
     * Notes:
     * 1. Implementors must have a no-arg constructor.
     *
     * 2. No internal caching intended; caller code should implement
     *    caching where it makes sense to do so, e.g., in loops.
     *
     * 3. Iteration facilities (e.g., `findNumChildren`, `getChildAt`)
     *    are provided for backwards compatibility. The linked list
     *    way of traversal should be preferred over iteration.
     *
     * 4. The same applies to route facilities (`findRoute`, `getByRoute`):
     *    `id` and `find` should be preferred.
     *
     * 5. You cannot `$set` Arrays or Objects directly. Provide your own
     *    `importFrom` implementation if you need to support that.
     */
    public interface IShard {

        // -------------------------
        // Properties
        // -------------------------

        /**
         * Returns the serialization format version of this Shard instance.
         * Subclasses can override this to signal schema upgrades.
         */
        function get formatVersion():uint;

        /**
         * Universally unique ID representing <this> element.
         */
        function get id():String;

        /**
         * The parent of <this> element.
         */
        function get parent():IShard;

        /**
         * The next sibling of <this> element (null if not applicable).
         */
        function get next():IShard;

        /**
         * The previous sibling of <this> element (null if not applicable).
         */
        function get prev():IShard;

        /**
         * The first child of <this> element (null if not applicable).
         */
        function get firstChild():IShard;

        /**
         * The last child of <this> element (null if not applicable).
         */
        function get lastChild():IShard;

        /**
         * Whether <this> element is flat, i.e., not accepting children.
         */
        function get isFlat():Boolean;

        /**
         * Whether <this> element is read-only (no mutation allowed).
         */
        function get isReadonly():Boolean;

        // -------
        // Methods
        // -------

        /**
         * Climbs all parents and returns the last.
         */
        function findRoot():IShard;

        /**
         * Counts and returns the current number of children.
         */
        function findNumChildren():int;

        /**
         * Computes and returns the depth level of <this> element. Root lives at `0`.
         */
        function findLevel():int;

        /**
         * Computes and returns the index of <this> element within its parent's children list.
         */
        function findIndex():int;

        /**
         * Compiles and returns a context-dependent unique ID of <this> element. It is built
         * by concatenating with underscores all indices from and including the root, down to
         * and including <this> element.
         * Example: -1_0_0_1.
         */
        function findRoute():String;

        /**
         * Looks up a content key.
         * @param keyName - The key to look up.
         * @return Returns `true` if key exists, `false` otherwise.
         */
        function has(keyName:String):Boolean;

        /**
         * Retrieves content by its key.
         * @param key - The key content is expected to live under.
         * @return Returns the matched content, which can be any primitive except `undefined`;
         *         `undefined` is a sign of a missing key.
         */
        function $get(key:String):*;

        /**
         * Stores or replaces content under a key.
         * @param key - Name of the key to store content under.
         * @param content - The content to store. Can be any primitive except `undefined`.
         * @throws If `content` is `undefined` or not a primitive.
         */
        function $set(key:String, content:*):void;

        /**
         * Obliterates content together with its key.
         * @param key - The key to delete related content of. Fails silently if `key` does
         *        not exist.
         * @return Returns the deleted value, which can be any primitive except `undefined`;
         *         `undefined` is a sign of a missing key.
         */
        function $delete(key:String):*;

        /**
         * Retrieves a child of <this> element by its index.
         * @param index - The 0-based index to locate a child by.
         * @return The matching child or `null` if not found.
         */
        function getChildAt(index:int):IShard;

        /**
         * Appends a child to <this> element, if permitted.
         * @param child - The child to append.
         */
        function addChild(child:IShard):void;

        /**
         * Inserts a child of <this> element at given index.
         * @param child - The child to insert.
         * @param atIndex - The 0-based index to insert the child at. Existing
         *        children will shift right.
         */
        function addChildAt(child:IShard, atIndex:int):void;

        /**
         * Removes a child from its parent together with all its descendants.
         * @param child - The child to remove. Fails silently if `child` is
         *        `null` or not a child of <this> element. Removed child becomes
         *        an orphan, and the root of its descendants, if applicable.
         * @return Returns `true` if removals succeeded, `false` otherwise.
         */
        function deleteChild(child:IShard):Boolean;

        /**
         * Splices and returns the child of <this> element at given index
         * together with all its descendants. Its next/right siblings will left shift.
         * Fails silently if `atIndex` is out of range. Removed child becomes an
         * orphan, and the root of its descendants, if applicable.
         * @param atIndex - The 0-based index to splice the child at.
         * @return The removed child if found, `null` otherwise.
         */
        function deleteChildAt(atIndex:int):IShard;

        /**
         * Removes all content and children of <this> element in one go.
         */
        function empty():void;

        /**
         * Creates a detached (deep) clone of <this> element. The clone is identical to
         * the original in all aspects except for the `id` value.
         * @param deep - Whether descendants must be cloned as well. Optional, default `false`.
         * @return The cloned element.
         */
        function clone(deep:Boolean = false):IShard;

        /**
         * The base implementation does not retain the `isReadonly` and `isFlat` settings in the
         * serialized format. Implement custom serialization or export if you need these.
         * 
         * Produces a ByteArray version of <this> element. The resulting ByteArray can be
         * imported back via `myElement.importFrom(myByteArray)`.
         */
        function toSerialized():ByteArray;

        /**
         * The base implementation does not provide an implementation of this method.
         *
         * Exports <this> element to a third-party format (discretionary to the implementor).
         * @param format - The name of the format to use, e.g., "JSON".
         * @param ...helpers - Optional. The argument can be used to inject various helpers
         *        (e.g., encoders, validators) into the method directly at runtime for better
         *        dependencies management.
         * @return The exported version of <this> element.
         */
        function exportTo(format:String, ... helpers):*;

        /**
         * The base implementation only imports from the native format.
         *
         * Empties <this> element (see `empty`), then populates it with imported data. The format of the
         * imported data can be native (see `toSerialized`) or third-party (discretionary to the implementor).
         * @param content - The content to import from. If using native format, this will be a ByteArray
         *        produced by `toSerialized()`. If using a third-party format, this will be any supported
         *        data.
         * @param format - The name of the format to use, e.g., "JSON". Not needed when importing from the
         *        native format.
         * @param ...helpers - Optional. The argument can be used to inject various helpers (e.g., encoders,
         *        validators) into the method directly at runtime for better dependencies management.
         */
        function importFrom(content:*, format:String = null, ... helpers):void;

        /**
         * Looks up and returns an element that is part of <this> element's "hierarchy". This includes
         * all element's descendants, the element itself, and all its ascendants, up to and including the
         * root.
         * @param route - The route to look up.
         * @return The matched element, or `null` if there was no match.
         */
        function getByRoute(route:String):IShard;

        /**
         * Checks if <this> element is deeply identical to an arbitrary other element. Two elements are
         * considered to be the same if they serialize to the exact same bytes.
         * @param other - The other element to compare to.
         * @return Returns `true` if identical, or `false` otherwise.
         */
        function isSame(other:IShard):Boolean;

        /**
         * Checks if <this> element has the same content keys as an arbitrary other element.
         * @param other - The other element to compare to.
         * @param deep - Whether to extend check to descendants as well. Optional, default false.
         * @return Returns `true` if identical, or `false` otherwise.
         */
        function isLike(other:IShard, deep:Boolean = false):Boolean;

        /**
         * Returns a debug-friendly String representation of <this> element.
         */
        function toString():String;

        /**
         * Searches the entire "hierarchy" of <this> element by arbitrary criteria.
         * @param what - What to search. If `how` is not given, `what` is assumed to be an `id`.
         *        Otherwise, `how` defines the way `what` is used.
         * @param how - How to search. Optional, default `null`. If given, can be a String or a Function.
         *        i) The String will be interpreted as the name of a "field" `what` is the expected value of.
         *        Base implementation supports content keys only.
         *        ii) The function will receive: the current test element, the `what` value and a `$break()`
         *        closure it can call to end search prematurely. Exact signature:
         *        function myTestFn (testEl : IShard, search: *, $breaker: Function) : Boolean;
         *        The function must return `true` for all elements that must be included in the result.
         * @return Returns matches as a (possibly empty) Vector of IShard implementors.
         */
        function find(what:*, how:Object = null):Vector.<IShard>;

        /**
         * Performs a depth-first traversal from the root of <this> element's "hierarchy" down to the
         * last leaf.
         * @param callback - The function to call for each element being visited. Receives as arguments the
         *        current element and a `$break()` closure it can call to end traversal prematurely.
         *        Exact signature:
         *        function myVisitingFn (el : IShard, $breaker: Function);
         */
        function all(callback:Function):void;

        /**
         * Performs a depth-first traversal from and including <this> element down to the last leaf of
         * any of its descendants.
         * @param callback - See `all()`.
         */
        function descendants(callback:Function):void;

        /**
         * Climbs from parent to parent, using <this> element as an anchor.
         * @param callback - See `all()`.
         */
        function parents(callback:Function):void;

        /**
         * Visits all children of <this> element in natural age order.
         * @param callback - See `all()`.
         */
        function children(callback:Function):void;

        /**
         * Visits all children of <this> element in reverse age order.
         * @param callback - See `all()`.
         */
        function childrenReverse(callback:Function):void;

        /**
         * Visits all right-hand siblings <this> element has.
         * @param callback - See `all()`.
         */
        function siblings(callback:Function):void;

        /**
         * Visits all left-hand siblings <this> element has.
         * @param callback - See `all()`.
         */
        function siblingsReverse(callback:Function):void;
    }
}
