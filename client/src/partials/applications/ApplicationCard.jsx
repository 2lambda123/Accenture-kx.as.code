import React from 'react';
import { Link } from 'react-router-dom';
import EditMenu from '../EditMenu';
import { TrashCan32, Restart32 } from '@carbon/icons-react';
import StatusTag from '../StatusTag';
import StatusPoint from '../StatusPoint';

function ApplicationCard(props) {
  const appId = props.app.appName.replaceAll(" ", "-").replace(/\b\w/g, l => l.toLowerCase());

  return (
    <div className="flex flex-col col-span-full sm:col-span-6 xl:col-span-4 bg-inv2 shadow-lg rounded"
      loading="lazy">
      <div className="p-6">
        <header className="flex justify-between items-start mb-2">
          {/* Icon */}
          <div className="flex content-start">
            <div className="bg-ghBlack rounded-full h-12 w-12" alt="Icon 02"></div>
            {/* <StatusTag installStatus={props.app.queueName} /> */}
          </div>
          {/* Menu button */}
          <EditMenu className="relative inline-flex">
            <li>
              <Link className="font-medium text-sm text-white hover:text-gray-500 flex py-1 px-3" to="#0">
                <div className="flex items-start">
                  <Restart32 className="p-1 flex my-auto" />
                </div>
                <span className="flex my-auto">Reinstall</span>
              </Link>
            </li>
            <li>
              <Link className="font-medium text-sm text-white hover:text-gray-500 flex py-1 px-3" to="#0">
                <div className="flex items-start">
                  <Restart32 className="p-1 flex my-auto" />
                </div>
                <span className="flex my-auto">Reinstall</span>
              </Link>
            </li>
            <li>
              <Link className="font-medium text-sm text-red-500 hover:text-red-600 flex py-1 px-3" to="#0">
                <div className="flex items-start">
                  <TrashCan32 className="p-1 flex my-auto" />
                </div>
                <span className="flex my-auto">Uninstall</span>
              </Link>
            </li>
          </EditMenu>
        </header>
        <Link to={'/apps/' + appId}>
          <h2 className="hover:underline hover:cursor-pointer text-lg text-white mb-2 flex items-center">
            <StatusPoint installStatus={props.app.queueName} />
            {props.app.appName} ({props.app.category}) </h2>
        </Link>
        <div className="text-xs font-semibold text-gray-400 uppercase mb-1">

        </div>
      </div>

      <div className="flex-grow">

      </div>
    </div>
  );
}

export default ApplicationCard;