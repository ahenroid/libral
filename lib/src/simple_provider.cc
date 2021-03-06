#include <libral/simple_provider.hpp>

#include <iostream>
#include <string>

#include <boost/algorithm/string.hpp>
#include <leatherman/execution/execution.hpp>

#include <leatherman/locale/locale.hpp>
#include <leatherman/logging/logging.hpp>

#include <libral/result.hpp>

#include <cstdio>

using namespace leatherman::locale;

namespace libral {

  result<changes>
  simple_provider::simple_resource::update(const attr_map &should) {
    std::vector<std::string> args;
    result<changes> rslt;
    auto& chgs = rslt.ok();

    auto cb = [this, &chgs](std::string& key, std::string& value)
      -> result<bool> {
      if (key == "name") {
        if (value != name()) {
          return error(_("wrong name changed by update: '{1}' instead of '{2}'",
                         value, name()));
        }
      } else if (key == "ral_was") {
        chgs.back().was = value;
      } else {
        chgs.push_back(change(key, value));
        (*this)[key] = value;
      }
      return true;
    };

    for (auto p : should) {
      args.push_back(p.first + "='" + p.second.to_string() + "'");
    }
    auto r = _prov->run_action("update", cb, args);
    if (!r) {
      return r.err();
    } else {
      return rslt;
    }
  }

  result<prov::spec> simple_provider::describe() {
    return prov::spec::read(_path, _node);
  }

  result<bool> simple_provider::suitable() {
    auto meta = _node["provider"];
    if (! meta.IsMap()) {
      return error(_("expected 'provider' key in metadata to contain a map"));
    }
    auto s = meta["suitable"].as<std::string>();
    if (s != "true" && s != "false") {
      return error(_("provider {1} (simple): metadata 'suitable' must be either 'true' or 'false' but was '{2}'", _path, s));
    }
    return (s == "true");
  }

  void simple_provider::flush() {
    // Noop. Not supported/needed
  }

  std::unique_ptr<resource> simple_provider::create(const std::string& name) {
    auto shared_this =
      std::static_pointer_cast<simple_provider>(shared_from_this());
    return std::unique_ptr<resource>(new simple_resource(shared_this, name));
  }

  result<boost::optional<resource_uptr>>
  simple_provider::find(const std::string &name) {
    resource_uptr rsrc;

    auto cb = [this, &rsrc, &name](std::string key, std::string value) -> result<bool> {
      if (key == "name") {
        rsrc = create(value);
        return true;
      } else if (key == "ral_unknown") {
        return error(_("unknown resource %s", name));
      } else {
        (*rsrc)[key] = value;
        return true;
      }
    };

    auto r = run_action("find", cb, { "name='" + name + "'" });
    if (!r) {
      return r.err();
    }

    return boost::optional<resource_uptr>(std::move(rsrc));
  }

  result<std::vector<resource_uptr>> simple_provider::instances() {
    // run script with ral_action == list
    std::vector<resource_uptr> res;
    std::unique_ptr<resource> rsrc;

    auto cb = [this, &res, &rsrc](std::string key, std::string value) {
      if (key == "name") {
        if (rsrc != nullptr) {
          res.push_back(std::move(rsrc));
        }
        rsrc = create(value);
      } else {
        (*rsrc)[key] = value;
      }
      return true;
    };
    auto r = run_action("list", cb);
    if (rsrc) {
      res.push_back(std::move(rsrc));
    }
    if (!r) {
      return r.err();
    };
    return std::move(res);
  }

  result<bool>
  simple_provider::run_action(const std::string& action,
         std::function<result<bool>(std::string&, std::string&)> entry_cb,
         std::vector<std::string> args) {
    int line_cnt = 0;
    bool in_error = false;
    result<bool> rslt = true;
    std::string errmsg;

    args.push_back("ral_action=" + action);
    auto err_cb = [&errmsg](std::string &line) {
      errmsg += line;
      return true;
    };
    auto out_cb = [&line_cnt,&in_error,&errmsg,&entry_cb,&rslt](std::string &line) {
      line_cnt +=1;
      if (line_cnt == 1) {
        if (line != "# simple") {
          rslt = error(_("invalid line: '%s'. Expected '# simple'", line));
        }
      } else if (in_error) {
        if (line != "ral_eom") {
          errmsg += line;
        } else {
          rslt = error(errmsg);
        }
      } else {
        size_t pos = line.find_first_of(":");
        if (pos == std::string::npos) {
          rslt = error(_("invalid line: '%s'. Expected '<KEY>: <VALUE>' but couldn't find a ':'", line));
        }
        auto key = line.substr(0, pos);
        auto value = line.substr(pos+1);
        boost::trim(value);
        if (key == "ral_error") {
          in_error = true;
          errmsg = value;
        } else {
          auto r = entry_cb(key, value);
          if (r.is_err()) {
            rslt = r;
          }
        }
      }
      return rslt.is_ok();
    };
    auto r = leatherman::execution::each_line(_path, args, out_cb, err_cb);
    if (! r && rslt.is_ok()) {
      if (errmsg.empty()) {
        rslt = error(_("Something went wrong running %s ral_action=%s",
                       _path, action));
      } else {
        rslt = error(_("Something went wrong running %s ral_action=%s\n%s",
                       _path, action, errmsg));
      }
    }
    return rslt;
  }
}
