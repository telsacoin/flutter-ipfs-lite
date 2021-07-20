import 'Block.dart';

abstract class BlockStore {

  static BlockStore createBlockStore(final Storage storage) {
        return new BlockStore() {
            @Override
            public boolean hasBlock(@NonNull Cid cid) {
                String key = Dshelp.cidToDsKey(cid).getKey();
                return storage.hasBlock(key);
            }

            @Override
            public Block getBlock(@NonNull Cid cid) {

                String key = Dshelp.cidToDsKey(cid).getKey();
                byte[] data = storage.getData(key);
                if (data == null) {
                    return null;
                }
                return BasicBlock.createBlockWithCid(cid, data);
            }

            @Override
            public void putBlock(@NonNull Block block) {
                String key = Dshelp.cidToDsKey(block.getCid()).getKey();
                storage.insertBlock(key, block.getRawData());
            }

            @Override
            public int getSize(@NonNull Cid cid) {
                String key = Dshelp.cidToDsKey(cid).getKey();
                return storage.sizeBlock(key);
            }

            public void deleteBlock(@NonNull Cid cid) {
                String key = Dshelp.cidToDsKey(cid).getKey();
                storage.deleteBlock(key);
            }

            @Override
            public void deleteBlocks(@NonNull List<Cid> cids) {
                for (Cid cid : cids) {
                    deleteBlock(cid);
                }
            }

        };
    }

    bool hasBlock(Cid cid);

    Block getBlock(Cid cid);

    void deleteBlock(Cid cid);

    void deleteBlocks(List<Cid> cids);

    void putBlock(Block block);

    int getSize(Cid cid);
}
