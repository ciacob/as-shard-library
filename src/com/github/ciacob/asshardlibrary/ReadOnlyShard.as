package com.github.ciacob.asshardlibrary {

    public class ReadOnlyShard extends Shard {

        private var _locked:Boolean = false;

        public function ReadOnlyShard(content:* = null) {
            super();

            if (content is IShard) {
                this.importFrom((content as IShard).toSerialized());
                _locked = true;
            } else if (content is Object) {
                for (var key:String in content) {
                    this.$set(key, content[key]);
                }
                _locked = true;
            }
        }

        override public function get isReadonly():Boolean {
            return _locked;
        }
    }
}
