import { MusicContentCenterVendorId } from "@shengwang/rtc-full";

/**
 * 音乐资源数据模型
 */
export class MusicResource {
  index: number;
  songCode: string;
  songName: string;
  vendorId: number;
  songType: number;
  songOptionJson: string;

  constructor(
    index: number,
    songCode: string,
    songName: string,
    vendorId: number,
    songType: number,
    songOptionJson: string
  ) {
    this.index = index;
    this.songCode = songCode;
    this.songName = songName;
    this.vendorId = vendorId;
    this.songType = songType;
    this.songOptionJson = songOptionJson;
  }
}

/**
 * 音乐资源池
 * 管理不同供应商的音乐资源
 */
export class MusicResourcePool {
  /**
   * 获取Vendor1(默认供应商)的音乐列表
   * @returns Vendor1音乐资源列表
   */
  static getVendor1MusicList(): MusicResource[] {
    const list: MusicResource[] = [];

    list.push(new MusicResource(
      0,
      "7162848775797850",
      "爱情转移",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    list.push(new MusicResource(
      1,
      "7104926139658410",
      "说爱你",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    list.push(new MusicResource(
      2,
      "7162848696618210",
      "Love Story",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    list.push(new MusicResource(
      3,
      "6246262727302510",
      "测试歌曲",
      MusicContentCenterVendorId.DEFAULT,
      4,
      ""
    ));

    return list;
  }

  /**
   * 获取Vendor2(第三方供应商)的音乐列表
   * @returns Vendor2音乐资源列表
   */
  static getVendor2MusicList(): MusicResource[] {
    const list: MusicResource[] = [];

    list.push(new MusicResource(
      0,
      "89488966",
      "在你的身边",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      "{\"format\":{\"highPart\":1}}"
    ));

    list.push(new MusicResource(
      1,
      "310937426",
      "怀抱",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      2,
      "621162805",
      "梦回花事了",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      3,
      "288308118",
      "还是分开",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      4,
      "130598261",
      "火力全开",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    // 测试用的歌曲
    list.push(new MusicResource(
      5,
      "613544010",
      "测试歌曲1",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      6,
      "332492815",
      "测试歌曲2",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    list.push(new MusicResource(
      7,
      "32144422",
      "测试歌曲3",
      MusicContentCenterVendorId.VENDOR_2,
      4,
      ""
    ));

    return list;
  }

  /**
   * 根据供应商ID获取音乐列表
   * @param vendorId - 供应商ID
   * @returns 对应供应商的音乐资源列表
   */
  static getMusicListByVendor(vendorId: MusicContentCenterVendorId): MusicResource[] {
    switch (vendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        return MusicResourcePool.getVendor1MusicList();
      case MusicContentCenterVendorId.VENDOR_2:
        return MusicResourcePool.getVendor2MusicList();
      default:
        return MusicResourcePool.getVendor1MusicList();
    }
  }

  /**
   * 获取所有音乐资源
   * @returns 所有音乐资源列表
   */
  static getAllMusicList(): MusicResource[] {
    const allList: MusicResource[] = [];
    allList.push(...MusicResourcePool.getVendor1MusicList());
    allList.push(...MusicResourcePool.getVendor2MusicList());
    return allList;
  }
}
