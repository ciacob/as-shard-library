package com.github.ciacob.asshardlibrary {
    import flash.utils.getQualifiedClassName;
    import flash.utils.getDefinitionByName;

    use namespace shard_internal;

    public class Shard extends AbstractShard implements IShard {
        public function Shard () {
            super();
        }

        override public function exportTo(format:String, ...helpers):* {
            if (format === "JSON") {
                const jsonObject:Object = buildJsonExport(this);
                return JSON.stringify(jsonObject);
            }
            return super.exportTo(format, helpers);
        }

        override public function importFrom(content:*, format:String = null, ...helpers):void {
            if (format === "JSON" && content is String) {
                const data:Object = JSON.parse(content);
                fromJsonImport(this, data, helpers);
                return;
            }

            // Defer to base class for other formats (e.g. ByteArray)
            super.importFrom(content, format, helpers);
        }

        private function buildJsonExport(shard:IShard):Object {
            const obj:Object = {};
            obj.fqn = getQualifiedClassName(shard);
            obj.intrinsic = { isFlat: shard.isFlat };

            const content:Object = {};
            for (var k:String in AbstractShard(shard)._content) {
                content[k] = AbstractShard(shard)._content[k];
            }
            obj.content = content;

            const children:Array = [];
            var current:IShard = shard.firstChild;
            while (current) {
                children.push(buildJsonExport(current));
                current = current.next;
            }
            obj.children = children;

            return obj;
        }

        private function fromJsonImport(target:IShard, data:Object, helpers:Array):void {
            helpers ||= [];

            target.empty();

            // Content
            for (var key:String in data.content) {
                target.$set(key, data.content[key]);
            }

            // Children
            for each (var childData:Object in data.children) {
                var child:IShard;
                try {
                    const cls:Class = Class(getDefinitionByName(childData.fqn));
                    child = new cls() as IShard;
                } catch (e:*) {
                    child = new Shard(); // Fallback to default
                }

                fromJsonImport(child, childData, helpers);
                target.addChild(child);
            }
        }
    }
}
