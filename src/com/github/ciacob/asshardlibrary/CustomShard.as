package com.github.ciacob.asshardlibrary {

    public class CustomShard extends AbstractShard {
        public function CustomShard() {
            super();
            $set("customized", true); // For testing
        }

        override public function get formatVersion():uint {
            return 2; // Just to prove subclassing control
        }
    }
}
