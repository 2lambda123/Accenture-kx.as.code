import React, { useEffect, useState } from 'react';
import {
  Switch,
  Route,
  useLocation
} from 'react-router-dom';

import './css/style.scss';

import { focusHandling } from 'cruip-js-toolkit';
import './charts/ChartjsConfig';

// Import pages
import Dashboard from './pages/Dashboard';
import Applications from "./pages/Applications";

import Sidebar from './partials/Sidebar';
import Header from './partials/Header';
import Settings from './pages/Settings';
import BasicBreadcrumbs from './partials/BasicBreadcrumbs';
import ExampleApp1 from './partials/ExampleApp1';
import AppDetails from "./pages/AppDetails"
import Home2 from './pages/Home';


function App() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const location = useLocation();

  useEffect(() => {
    document.querySelector('html').style.scrollBehavior = 'auto'
    window.scroll({ top: 0 })
    document.querySelector('html').style.scrollBehavior = ''
    focusHandling('outline');
  }, [location.pathname]); // triggered on route change

  return (
    <>
      <div className="flex h-screen overflow-hidden bg-ghBlack">

        {/* Sidebar */}
        <Sidebar sidebarOpen={sidebarOpen} setSidebarOpen={setSidebarOpen} />

        {/* Content area */}
        <div className="relative flex flex-col flex-1 overflow-y-auto overflow-x-hidden">

          {/*  Site header */}
          <Header sidebarOpen={sidebarOpen} setSidebarOpen={setSidebarOpen} />

          <main>
              <BasicBreadcrumbs/>
              <Switch>
                <Route exact path="/" component={Home2}/>

                <Route exact path="/dashboard">
                  <Dashboard />
                </Route>
                <Route exact path="/apps">
                  <Applications />
                </Route>
                <Route exact path="/apps/example-app-1">
                  <ExampleApp1 />
                </Route>
                <Route exact path="/apps/example-app-1">
                  <ExampleApp1 />
                </Route>
                <Route exact path="/settings">
                  <Settings />
                </Route>
                <Route path="/apps/:appId" component={AppDetails} />
              </Switch>
          </main>
        </div>
      </div>
    </>
  );
}

export default App;
