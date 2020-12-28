import { hot } from "react-hot-loader";
import React, { Component } from "react";
import { library } from "@fortawesome/fontawesome-svg-core";
import { faChevronRight } from "@fortawesome/free-solid-svg-icons";
import { Box } from "@material-ui/core";
import intl from "react-intl-universal";
import IntlPolyfill from "intl";
import "./App.scss";
import TopPanel from "./layout/components/TopPanel";
import LeftPanel from "./layout/components/LeftPanel";
import { HashRouter, Route } from "react-router-dom";
import Home from "./components/home/Home";
import { NewProfileGeneral, NewProfileResource, NewProfileStorage, NewProfileReview, NewProfileOptional } from "./components/profile/index";


window.Intl = IntlPolyfill;
require("intl/locale-data/jsonp/en-US.js");
require("intl/locale-data/jsonp/de-DE.js");

const SUPPORTED_LOCALES = [
  {
    name: "English",
    value: "en-US",
  },
  {
    name: "Deutsch",
    value: "de-DE",
  },
];

library.add(faChevronRight);

class App extends Component {
  constructor() {
    super();
    const currentLocale = SUPPORTED_LOCALES[0].value; // Determine user's locale here
    intl.init({
      currentLocale,
      locales: {
        [currentLocale]: require(`./locales/${currentLocale}.json`),
      },
    });
  }

  render() {
    return (
      <Box id="App">
        {/* Top panel */}
        <Box id="TopPanel-wrapper">
          <HashRouter>
            <TopPanel />
          </HashRouter>
        </Box>
        {/* Main section - below top panel */}
        <Box id="main" flex="1">
          <Box id="main-container">
            {/* Left panel */}
            <Box id="LeftPanel-wrapper">
              <LeftPanel />
            </Box>
            {/* Content */}
            <Box id="content" >
              <HashRouter>
                <div>
                  <Route path="/" exact={true} component={Home} />
                  <Route path="/new-profile-general">
                    <NewProfileGeneral/>
                  </Route>
                  <Route path="/new-profile-resource">
                    <NewProfileResource/>
                  </Route>
                  <Route path="/new-profile-storage">
                    <NewProfileStorage/>
                  </Route>
                  <Route path="/new-profile-optional">
                    <NewProfileOptional/>
                  </Route>
                  <Route path="/new-profile-review">
                    <NewProfileReview/>
                  </Route>
                </div>
              </HashRouter>
            </Box>
          </Box>
        </Box>
      </Box>
    );
  }
}

export default hot(module)(App);
