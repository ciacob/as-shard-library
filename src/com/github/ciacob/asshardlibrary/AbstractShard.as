package com.github.ciacob.asshardlibrary {
    import flash.utils.ByteArray;
    import flash.net.registerClassAlias;
    import flash.utils.getQualifiedClassName;

    use namespace shard_internal;

    public class AbstractShard implements IShard {

        /**
         * Generates a v4-style UUID.
         */
        protected static function makeUuid():String {
            const hex:Function = function(c:int):String {
                const chars:String = "0123456789abcdef";
                return chars.charAt((c >> 4) & 0x0F) + chars.charAt(c & 0x0F);
            };

            const uuid:Array = [];
            for (var i:int = 0; i < 16; i++) {
                uuid[i] = Math.floor(Math.random() * 256);
            }

            uuid[6] = (uuid[6] & 0x0F) | 0x40; // version 4
            uuid[8] = (uuid[8] & 0x3F) | 0x80; // variant 10x

            return [hex(uuid[0]) + hex(uuid[1]) + hex(uuid[2]) + hex(uuid[3]),
                hex(uuid[4]) + hex(uuid[5]),
                hex(uuid[6]) + hex(uuid[7]),
                hex(uuid[8]) + hex(uuid[9]),
                hex(uuid[10]) + hex(uuid[11]) + hex(uuid[12]) + hex(uuid[13]) + hex(uuid[14]) + hex(uuid[15])].join("-");
        }


        // -----------------------
        // Static central registry
        // -----------------------
        shard_internal static const registry:Object = {};

        // -----------------------
        // Identity
        // -----------------------
        protected var _id:String;

        // -----------------------
        // Linkage UUIDs
        // -----------------------
        protected var _parentId:String;
        protected var _nextId:String;
        protected var _prevId:String;
        protected var _firstChildId:String;
        protected var _lastChildId:String;

        // -----------------------
        // Content
        // -----------------------
        protected var _content:Object = {};

        // -----------------------
        // Constructor
        // -----------------------
        /**
         * Creates a new, detached Shard instance with a unique identifier.
         * The instance is not yet part of any hierarchy.
         */
        public function AbstractShard() {
            const className:String = getQualifiedClassName(this);
            if (className === "ro.ciacob.desktop.data::AbstractShard") {
                throw new Error("AbstractShard is abstract and cannot be instantiated directly.");
            }

            _id = makeUuid();
            registry[_id] = this;
        }

        // -----------------------
        // Property accessors
        // -----------------------

        public function get id():String {
            return _id;
        }

        public function get parent():IShard {
            return registry[_parentId] || null;
        }

        public function get next():IShard {
            return registry[_nextId] || null;
        }

        public function get prev():IShard {
            return registry[_prevId] || null;
        }

        public function get firstChild():IShard {
            return registry[_firstChildId] || null;
        }

        public function get lastChild():IShard {
            return registry[_lastChildId] || null;
        }

        public function get isFlat():Boolean {
            return false; // default: can have children; override if needed
        }

        // ----------------
        // Content Mutation
        // ----------------
        public function has(keyName:String):Boolean {
            return keyName in _content;
        }

        public function $get(key:String):* {
            return has(key) ? _content[key] : undefined;
        }

        public function $set(key:String, content:*):void {
            if (content === undefined || typeof content === "object") {
                throw new ArgumentError("Shard - $set(): Content must be a primitive (non-object), not undefined.");
            }
            _content[key] = content;
        }

        public function $delete(key:String):* {
            if (!has(key)) {
                return undefined;
            }
            const removed:* = _content[key];
            delete _content[key];
            return removed;
        }

        // --------------
        // Child Mutation
        // --------------
        public function addChild(child:IShard):void {
            addChildAt(child, findNumChildren());
        }

        public function addChildAt(child:IShard, atIndex:int):void {

            // Check we're allowed to have children, and we have a valid child.
            if (isFlat || child == null) {
                return;
            }

            // Silently normalize the target index.
            if (atIndex < 0) {
                atIndex = 0;
            } else {
                const numChildren : uint = findNumChildren();
                if (atIndex > numChildren) {
                    atIndex = numChildren;
                }
            }

            // Prevent circular ancestry.
            // We prevent adding parent or self or any ancestor as a child.
            // However, adopting "cousins" is allowed, and so is adopting any childless
            // "uncles".
            var current:IShard = this;
            while (current) {
                if (current === child) {
                    return;
                }
                current = current.parent;
            }

            // Proceed with rewiring logic
            const oldParent:AbstractShard = child.parent as AbstractShard;
            if (oldParent) {
                oldParent.unwireChild(child);
            }

            const insertAfter:IShard = getChildAt(atIndex - 1);
            const insertBefore:IShard = (insertAfter != null) ? insertAfter.next : firstChild;

            // Wire new child into the list
            const shardChild:AbstractShard = AbstractShard(child);
            shardChild._parentId = this.id;
            shardChild._prevId = insertAfter ? insertAfter.id : null;
            shardChild._nextId = insertBefore ? insertBefore.id : null;

            if (insertAfter) {
                AbstractShard(insertAfter)._nextId = shardChild.id;
            } else {
                _firstChildId = shardChild.id;
            }

            if (insertBefore) {
                AbstractShard(insertBefore)._prevId = shardChild.id;
            } else {
                _lastChildId = shardChild.id;
            }

            // If list was empty
            if (!_firstChildId)
                _firstChildId = shardChild.id;
            if (!_lastChildId)
                _lastChildId = shardChild.id;
        }

        protected function unwireChild(child:IShard):Boolean {
            if (child == null || child.parent !== this) {
                return false;
            }

            const shardChild:AbstractShard = AbstractShard(child);
            const prev:IShard = shardChild.prev;
            const next:IShard = shardChild.next;

            if (prev)
                AbstractShard(prev)._nextId = next ? next.id : null;
            if (next)
                AbstractShard(next)._prevId = prev ? prev.id : null;

            if (_firstChildId === shardChild.id)
                _firstChildId = next ? next.id : null;
            if (_lastChildId === shardChild.id)
                _lastChildId = prev ? prev.id : null;

            shardChild._parentId = null;
            shardChild._prevId = null;
            shardChild._nextId = null;

            return true;
        }

        protected function unwireChildAt(atIndex:int):IShard {
            const child:IShard = getChildAt(atIndex);
            return unwireChild(child) ? child : null;
        }

        public function deleteChild(child:IShard):Boolean {
            if (!unwireChild(child))
                return false;

            function recursiveWipe(shard:IShard):void {
                var current:AbstractShard = AbstractShard(shard);
                var kid:IShard = shard.firstChild;
                while (kid) {
                    var next:IShard = kid.next; // Save next before wiping
                    recursiveWipe(kid);
                    kid = next;
                }
                delete registry[current.id];
            }

            recursiveWipe(child);
            return true;
        }

        public function deleteChildAt(atIndex:int):IShard {
            const child:IShard = getChildAt(atIndex);
            return deleteChild(child) ? child : null;
        }

        public function getChildAt(index:int):IShard {
            var current:IShard = firstChild;
            var i:int = 0;
            while (current && i < index) {
                current = current.next;
                i++;
            }
            return (i === index) ? current : null;
        }

        public function findNumChildren():int {
            var count:int = 0;
            var current:IShard = firstChild;
            while (current) {
                count++;
                current = current.next;
            }
            return count;
        }

        public function empty():void {
            // Remove all content keys
            for (var key:String in _content) {
                delete _content[key];
            }

            // Detach all children
            var current:IShard = firstChild;
            while (current) {
                var next:IShard = current.next;
                AbstractShard(current)._parentId = null;
                AbstractShard(current)._prevId = null;
                AbstractShard(current)._nextId = null;
                current = next;
            }

            _firstChildId = null;
            _lastChildId = null;

            // TODO: actually remove the elements from the static registry?
        }

        public function findIndex():int {
            if (!parent)
                return -1;

            var index:int = 0;
            var current:IShard = parent.firstChild;
            while (current && current !== this) {
                index++;
                current = current.next;
            }
            return (current === this) ? index : -1;
        }

        public function findLevel():int {
            var level:int = 0;
            var current:IShard = parent;
            while (current) {
                level++;
                current = current.parent;
            }
            return level;
        }

        public function findRoute():String {
            var indices:Array = [];
            var current:IShard = this;
            while (current) {
                indices.unshift(current.findIndex());
                current = current.parent;
            }
            return indices.join("_");
        }

        public function findRoot():IShard {
            var current:IShard = this;
            while (current.parent) {
                current = current.parent;
            }
            return current;
        }

        public function getByRoute(route:String):IShard {
            const segments:Array = route.split("_");
            var current:IShard = findRoot();

            for (var i:int = 1; i < segments.length; i++) {
                var index:int = parseInt(segments[i], 10);
                if (isNaN(index))
                    return null;
                current = current.getChildAt(index);
                if (!current)
                    return null;
            }

            return current;
        }

        public function isLike(other:IShard, deep:Boolean = false):Boolean {
            if (!other)
                return false;

            const selfKeys:Array = [];
            const otherKeys:Array = [];

            for (var k:String in _content)
                selfKeys.push(k);
            for (k in AbstractShard(other)._content)
                otherKeys.push(k);

            selfKeys.sort();
            otherKeys.sort();

            if (selfKeys.join(",") !== otherKeys.join(","))
                return false;

            if (deep) {
                var selfChild:IShard = firstChild;
                var otherChild:IShard = other.firstChild;
                while (selfChild && otherChild) {
                    if (!selfChild.isLike(otherChild, true))
                        return false;
                    selfChild = selfChild.next;
                    otherChild = otherChild.next;
                }
                return (!selfChild && !otherChild);
            }

            return true;
        }

        public function clone(deep:Boolean = false):IShard {
            var copy:AbstractShard;
            try {
                const constructor:Class = (this as Object).constructor as Class;
                copy = new constructor();
            } catch (e:Error) {
                throw new Error("Cannot clone: AbstractShard subclasses must have a no-arg constructor.");
            }

            // Copy content
            for (var key:String in _content) {
                copy._content[key] = _content[key];
            }

            // Recursively clone children
            if (deep) {
                var child:IShard = firstChild;
                while (child) {
                    copy.addChild(child.clone(true));
                    child = child.next;
                }
            }

            return copy;
        }

        public function toSerialized():ByteArray {
            const alias:String = "ro.ciacob.desktop.data.AbstractShard";
            registerClassAlias(alias, AbstractShard);

            const b:ByteArray = new ByteArray();
            b.writeObject(this);
            b.position = 0;
            b.compress();
            return b;
        }

        public function importFrom(content:*, format:String = null, ... helpers):void {
            empty();

            if (!format && content is ByteArray) {
                const input:ByteArray = ByteArray(content);
                input.uncompress();
                input.position = 0;

                const source:AbstractShard = input.readObject() as AbstractShard;
                if (!source)
                    return;

                // Copy content
                for (var key:String in source._content) {
                    _content[key] = source._content[key];
                }

                // Deep-clone children (without reusing IDs)
                var child:IShard = source.firstChild;
                while (child) {
                    addChild(child.clone(true));
                    child = child.next;
                }
            }

            // Otherwise, leave for subclasses to override
        }

        public function isSame(other:IShard):Boolean {
            if (!other || other.isFlat !== this.isFlat) {
                return false;
            }

            // Compare content keys and values
            const thisKeys:Array = [];
            const otherKeys:Array = [];

            for (var k:String in _content)
                thisKeys.push(k);
            for (k in AbstractShard(other)._content)
                otherKeys.push(k);

            thisKeys.sort();
            otherKeys.sort();

            if (thisKeys.length !== otherKeys.length)
                return false;
            for (var i:int = 0; i < thisKeys.length; i++) {
                if (thisKeys[i] !== otherKeys[i])
                    return false;

                const key:String = thisKeys[i];
                if (_content[key] !== AbstractShard(other)._content[key]) {
                    return false;
                }
            }

            // Recursively compare children
            var a:IShard = this.firstChild;
            var b:IShard = other.firstChild;

            while (a && b) {
                if (!a.isSame(b))
                    return false;
                a = a.next;
                b = b.next;
            }

            return (a === null && b === null); // Ensure same length
        }

        public function all(callback:Function):void {
            const root:IShard = findRoot();
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            function dfs(node:IShard):void {
                if ($breakFlag.broken)
                    return;
                callback(node, $break);
                var child:IShard = node.firstChild;
                while (child) {
                    dfs(child);
                    if ($breakFlag.broken)
                        return;
                    child = child.next;
                }
            }

            dfs(root);
        }

        public function descendants(callback:Function):void {
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            function dfs(node:IShard):void {
                if ($breakFlag.broken)
                    return;
                callback(node, $break);
                var child:IShard = node.firstChild;
                while (child) {
                    dfs(child);
                    if ($breakFlag.broken)
                        return;
                    child = child.next;
                }
            }

            var start:IShard = firstChild;
            while (start) {
                dfs(start);
                if ($breakFlag.broken)
                    return;
                start = start.next;
            }
        }

        public function parents(callback:Function):void {
            var current:IShard = parent;
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            while (current && !$breakFlag.broken) {
                callback(current, $break);
                current = current.parent;
            }
        }

        public function children(callback:Function):void {
            var current:IShard = firstChild;
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            while (current && !$breakFlag.broken) {
                callback(current, $break);
                current = current.next;
            }
        }

        public function childrenReverse(callback:Function):void {
            var current:IShard = lastChild;
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            while (current && !$breakFlag.broken) {
                callback(current, $break);
                current = current.prev;
            }
        }

        public function siblings(callback:Function):void {
            var current:IShard = next;
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            while (current && !$breakFlag.broken) {
                callback(current, $break);
                current = current.next;
            }
        }

        public function siblingsReverse(callback:Function):void {
            var current:IShard = prev;
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            while (current && !$breakFlag.broken) {
                callback(current, $break);
                current = current.prev;
            }
        }

        public function find(what:*, how:Object = null):Vector.<IShard> {
            const results:Vector.<IShard> = new Vector.<IShard>();
            const $breakFlag:Object = {broken: false};
            const $break:Function = function():void {
                $breakFlag.broken = true;
            };

            function test(shard:IShard):Boolean {
                if (how == null) {
                    return shard.id === what;
                }
                if (typeof how === "string") {
                    return shard.has(how as String) && shard.$get(how as String) === what;
                }
                if (how is Function) {
                    return (how as Function)(shard, what, $break);
                }
                return false;
            }

            findRoot().all(function(el:IShard, breaker:Function):void {
                if ($breakFlag.broken)
                    return;
                if (test(el))
                    results.push(el);
            });

            return results;
        }

        public function toString():String {
            return "[Shard id=\"" + id + "\", route=\"" + findRoute() + "\"]";
        }

        public function exportTo(format:String, ... helpers):* {
            throw new Error("AbstractShard does not support exportTo(). Please subclass and implement this method.");
        }

    }
}
