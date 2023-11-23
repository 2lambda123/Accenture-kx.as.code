import React, { useState, useEffect } from "react";
import Tooltip from "@mui/material/Tooltip";
import Button from "@mui/material/Button";

interface ApplicationCategoryTagProps {
  appTag: string;
  addCategoryTofilterTags: (tag: { name: string }) => void;
}

const ApplicationCategoryTag: React.FC<ApplicationCategoryTagProps> = ({
  appTag,
  addCategoryTofilterTags,
}) => {
  const [appTagTransformed, setAppTagTransformed] = useState("");

  useEffect(() => {
    setAppTagTransformed(
      appTag.replaceAll("-", " ").replaceAll("_", " ").replace(/\b\w/g, (l) => l.toUpperCase())
    );
  }, [appTag]);

  return (
    <Tooltip title="Add to filters" placement="top" arrow>
      <Button
        id={appTag}
        className="bg-gray-500 hover:bg-kxBlue text-xs mr-1.5 px-2 w-auto inline-block text-black rounded-none py-1"
        onClick={() => {
          const tagObj = { name: appTag };
          addCategoryTofilterTags(tagObj);
        }}
      >
        {appTagTransformed}
      </Button>
    </Tooltip>
  );
};

export default ApplicationCategoryTag;