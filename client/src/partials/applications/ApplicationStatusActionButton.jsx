import React from "react";
import { Link } from "react-router-dom";
import { ImCross } from "react-icons/im";
import { FaArrowAltCircleDown } from "react-icons/fa";
import { AiOutlineWarning } from "react-icons/ai";
import RestartAltIcon from '@mui/icons-material/RestartAlt';
import Tooltip from "@mui/material/Tooltip";

import { useState, useEffect } from "react";

export default function ApplicationStatusActionButton(props) {
  useEffect(() => {
    console.log("list-actionbutton: ", props.getQueueStatusList(props.appName));
    return () => { };
  }, []);

  const getActionButton = () => {
    if (!props.isMqConnected) { // TODO: Disable in API Mock Mode
      if (props.getQueueStatusList(props.appName) == "pending_queue") {
        return (
          <div className="flex">
            <button
              className="bg-gray-600 p-2 px-5 rounded-bl rounded-tl items-center flex"
              disabled
            >
              <svg
                className="animate-spin -ml-1 mr-3 h-5 w-5 text-white"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  className="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  strokeWidth="4"
                ></circle>
                <path
                  className="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                ></path>
              </svg>
              <span className="text-white">Processing...</span>
            </button>
            <Tooltip title={`Re-install ${props.appName}`} placement="top" arrow>
              <button className="bg-kxBlue p-2 rounded-br rounded-tr">
                <RestartAltIcon
                  aria-label="list"
                  color="white"
                  onClick={() => {
                    props.applicationInstallHandler();
                  }}
                />
              </button>
            </Tooltip>
          </div>
        );
      } else if (
        props.getQueueStatusList(props.appName) == "completed_queue" &&
        props.category != "core"
      ) {
        return (
          <button
            className="bg-red-500 p-2 px-5 rounded items-center flex"
            to="#0"
            onClick={() => {
              props.applicationUninstallHandler();
            }}
          >
            <div className="flex items-start">
              <ImCross className="p-0.5 flex my-auto" />
            </div>
            <span className="flex my-auto">Uninstall</span>
          </button>
        );
      } else if (props.category != "core") {
        return (
          <button
            className="bg-kxBlue p-2 px-5 rounded items-center flex"
            to="#0"
            onClick={() => {
              props.applicationInstallHandler();
            }}
          >
            <div className="flex items-start">
              <FaArrowAltCircleDown className="mr-2 flex my-auto text-white" />
            </div>
            <span className="flex my-auto text-[16px]">Install</span>
          </button>
        );
      }
    } else {
      return (

        <button
          className="border-red-500 border p-2 px-5 rounded items-center flex text-red-500"
          to="#0"
          onClick={() => {
            props.applicationInstallHandler();
          }}
        >
          <span className="flex my-auto text-base">
            <AiOutlineWarning className="mt-auto mb-auto table text-lg mr-2" />
            ActionButton Error</span>
        </button>

      );
    }
  };

  useEffect(() => {
    return () => {
      // props.refreshActionButton.current = getActionButton;
    };
  }, []);

  return (
    <>
      <div className="">{getActionButton()}</div>

      {/* <div>
        {props.getQueNameNew(props.appName).map((q) => {
          return <div>{q}</div>;
        })}
      </div> */}
    </>
  );
}
