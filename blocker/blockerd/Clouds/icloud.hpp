//
//  icloud.hpp
//  blockerd
//
//  Created by Jozef on 05/06/2020.
//  Copyright © 2020 Jozef Zuzelka. All rights reserved.
//

#ifndef icloud_hpp
#define icloud_hpp

#include "base.hpp"

struct ICloud : public CloudProvider
{
    ICloud(const BlockLevel Bl, const std::vector<std::string> &Paths) {
        id = CloudProviderId::ICLOUD;
        bl = Bl;
        paths = Paths;
        allowedBundleIds = {
            "com.apple.bird",
        };
    };
    ~ICloud() = default;

    static std::vector<std::string> FindPaths(const std::string &homePath);
};

#endif /* icloud_hpp */
