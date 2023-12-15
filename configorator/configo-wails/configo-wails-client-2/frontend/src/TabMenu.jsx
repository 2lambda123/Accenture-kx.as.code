import React, { useState, useEffect } from 'react';
import Button from '@mui/material/Button';
import TextField from '@mui/material/TextField';
import FormControlLabel from '@mui/material/FormControlLabel';
import InputAdornment from '@mui/material/InputAdornment';
import Switch from '@mui/material/Switch';
import MenuItem from '@mui/material/MenuItem';
import Slider from '@mui/material/Slider';
import CodeMirror from '@uiw/react-codemirror';
import { historyField } from '@codemirror/commands';
import configJSON from './assets/config/config.json';
import { oneDark } from '@codemirror/theme-one-dark';
import { useNavigate } from 'react-router-dom';
import PlayCircleIcon from '@mui/icons-material/PlayCircle';
import CloudDownloadIcon from '@mui/icons-material/CloudDownload';
import UserTable from './UserTable';
import JSONConfigTabContent from './JSONConfigTabContent';
import GlobalVariablesTable from './GlobalVariablesTable';
import PersonAddAltIcon from '@mui/icons-material/PersonAddAlt';
import AddIcon from '@mui/icons-material/Add';
import AddCircleOutlineIcon from '@mui/icons-material/AddCircleOutline';
import { UpdateJsonFile } from "../wailsjs/go/main/App";
import FilledInput from '@mui/material/FilledInput';
import OutlinedInput from '@mui/material/OutlinedInput';
import InputLabel from '@mui/material/InputLabel';
import FormHelperText from '@mui/material/FormHelperText';
import FormControl from '@mui/material/FormControl';
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';
import IconButton from '@mui/material/IconButton';



const TabMenu = () => {
    const [activeTab, setActiveTab] = useState('tab1');
    const [activeConfigTab, setActiveConfigTab] = useState('config-tab1');
    const [jsonData, setJsonData] = useState('');
    const [updatedJsonData, setUpdatedJsonData] = useState('');

    const serializedState = localStorage.getItem('myEditorState');
    const value = localStorage.getItem('myValue') || '';
    const stateFields = { history: historyField };

    const handleConfigChange = (value, key) => {
        const selectedValue = value;

        let parsedData;
        try {
            parsedData = JSON.parse(jsonData);
        } catch (error) {
            console.error('Error parsing JSON:', error);
            return;
        }
        parsedData.config[key] = selectedValue;
        console.log("DEBUG: ", parsedData.config[key])
        console.log("DEBUG: selectedValue", selectedValue)
        const updatedJsonString = JSON.stringify(parsedData, null, 2);
        setJsonData(updatedJsonString);

        UpdateJsonFile(updatedJsonString)
    };

    const handleTabClick = (tab) => {
        setActiveTab(tab);
    };

    const handleConfigTabClick = (configTab) => {
        setActiveConfigTab(configTab);
    };

    const formatJSONData = () => {
        const jsonString = JSON.stringify(configJSON, null, 2);
        setJsonData(jsonString);
    }

    useEffect(() => {
        formatJSONData();
    }, [activeConfigTab, jsonData]);

    return (
        <div className=''>
            <div className='flex grid-cols-12 items-center'>
                <button onClick={() => handleConfigTabClick('config-tab1')} className={`${activeConfigTab === "config-tab1" ? "bg-kxBlue2" : ""} flex col-span-6 w-full text-center justify-center py-2`}>Config UI</button>
                <button onClick={() => handleConfigTabClick('config-tab2')} className={`${activeConfigTab === "config-tab2" ? "bg-kxBlue2" : ""} flex col-span-6 w-full text-center justify-center py-2`}>Config JSON</button>
            </div>

            <div className="config-tab-content">
                {activeConfigTab === 'config-tab1' && <UIConfigTabContent activeTab={activeTab} handleTabClick={handleTabClick} handleConfigChange={handleConfigChange} />}
                {activeConfigTab === 'config-tab2' && <JSONConfigTabContent jsonData={jsonData} />}
            </div>
            <BuildExecuteButton />
        </div>
    );
};

const BuildExecuteButton = () => {
    const navigate = useNavigate();

    const handleBuildClick = () => {
        console.log('KX.AS.Code Image build process started!');
        navigate('/console-output');
    };

    return (
        <div className=''>
            <button onClick={() => { handleBuildClick() }} className='bg-kxBlue p-3 w-full flex justify-center items-center'>
                <PlayCircleIcon className='mr-1' /> Build KX.AS.Code Image</button>
            <button className='p-3 w-full font-normal hover:text-gray-400 w-auto flex justify-center items-center'>
                <CloudDownloadIcon className='mr-1.5' /> Download Image from Vagrant Cloud</button>
        </div>
    )
}

const UIConfigTabContent = ({ activeTab, handleTabClick, handleConfigChange }) => (
    <div id='config-ui-container' className=''>
        <div className="flex bg-ghBlack4 text-sm">
            <button
                onClick={() => handleTabClick('tab1')}
                className={` ${activeTab === 'tab1' ? 'bg-kxBlue' : ''} p-3 py-1`}
            >
                Profile
            </button>
            <button
                onClick={() => handleTabClick('tab2')}
                className={` ${activeTab === 'tab2' ? 'bg-kxBlue' : ''} p-3 py-1`}
            >
                Parameters & Mode
            </button>
            <button
                onClick={() => handleTabClick('tab3')}
                className={` ${activeTab === 'tab3' ? 'bg-kxBlue' : ''} p-3 py-1`}
            >
                Resources
            </button>
            <button
                onClick={() => handleTabClick('tab4')}
                className={` ${activeTab === 'tab4' ? 'bg-kxBlue' : ''} p-3 py-1`}
            >
                Storage
            </button>
            <button
                onClick={() => handleTabClick('tab5')}
                className={` ${activeTab === 'tab5' ? 'bg-kxBlue' : ''} p-3 py-1`}
            >
                User Provisioning
            </button>
            <button
                onClick={() => handleTabClick('tab6')}
                className={` ${activeTab === 'tab6' ? 'bg-kxBlue' : ''} p-3 py-1`}
            >
                Custom Variables
            </button>
        </div>

        <div className="tab-content">
            {activeTab === 'tab1' && <TabContent1 handleConfigChange={handleConfigChange} />}
            {activeTab === 'tab2' && <TabContent2 handleConfigChange={handleConfigChange} />}
            {activeTab === 'tab3' && <TabContent3 handleConfigChange={handleConfigChange} />}
            {activeTab === 'tab4' && <TabContent4 handleConfigChange={handleConfigChange} />}
            {activeTab === 'tab5' && <TabContent5 handleConfigChange={handleConfigChange} />}
            {activeTab === 'tab6' && <TabContent6 handleConfigChange={handleConfigChange} />}
        </div>
    </div>
);

const TabContent1 = ({ handleConfigChange }) => {

    return (
        <div className='text-left'>
            <div className='px-5 py-3'>
                <h2 className='text-3xl font-semibold'>Profile</h2>
                <p className='text-sm text-gray-400 text-justify'>Select the profile. A check is made on the system to see if the necessary virtualization software and associated Vagrant plugins are installed, as well as availability of built Vagrant boxes.</p>
            </div>
            <div className='px-5 py-3 bg-ghBlack grid grid-cols-12'>
                <div className='col-span-6'>
                    <TextField
                        label="Profiles"
                        select
                        fullWidth
                        variant="outlined"
                        size="small"
                        margin="normal"
                        defaultValue="virtualbox"
                    >
                        <MenuItem value="virtualbox">Virtualbox</MenuItem>
                        <MenuItem value="parallels">Parallels</MenuItem>
                        <MenuItem value="vmware-desktop">VMWare Desktop</MenuItem>
                    </TextField>

                    <TextField
                        label="Start Mode"
                        select
                        fullWidth
                        variant="outlined"
                        size="small"
                        margin="normal"
                        defaultValue="normal"
                        onChange={(e) => { handleConfigChange(e.target.value, "startupMode") }}
                    >
                        <MenuItem value="normal">Normal</MenuItem>
                        <MenuItem value="lite">Lite</MenuItem>
                        <MenuItem value="minimal">Minimal</MenuItem>
                    </TextField>

                    <TextField
                        label="Orchestrator"
                        select
                        fullWidth
                        variant="outlined"
                        size="small"
                        margin="normal"
                        defaultValue="k3s"
                        onChange={(e) => { handleConfigChange(e.target.value, "kubeOrchestrator") }}
                    >
                        <MenuItem value="k8s">K8s</MenuItem>
                        <MenuItem value="k3s">K3s</MenuItem>
                    </TextField>
                </div>
            </div>
        </div>
    )
};

const TabContent2 = ({ handleConfigChange }) => {
    const [showPassword, setShowPassword] = React.useState(false);

    const handleClickShowPassword = () => setShowPassword((show) => !show);

    const handleMouseDownPassword = (event) => {
        event.preventDefault();
    };

    return (
        <div className='text-left'>
            <div className='px-5 py-3'>
                <h2 className='text-3xl font-semibold'>General Parameters & Mode Selection</h2>
                <p className='text-sm text-gray-400 text-justify'> Set the parameters to define the internal DNS of KX.AS.CODE.
                    {/* Set the parameters to define the internal DNS of KX.AS.CODE. Each new service that is provisioned in KX.AS.CODE will have the fully qualified domain name (FQDN) of &lt;service_name&gt;, &lt;team_name&gt;. &lt;base_domain&gt;. The username and password fields determine the base admin user password. It is possible to add additional users. In the last section, you determine if running in standalone or cluster mode. Standalone mode starts up one main node only. This is recommended for any physical environment with less than 16G ram. If enable worker nodes, then you can also choose to have workloads running on both main and worker nodes, or only on worker nodes. */}
                </p>
            </div>
            <div className='px-5 py-3 bg-ghBlack grid grid-cols-12'>
                <div className='col-span-6'>
                    <h2 className='text-xl font-semibold text-gray-400'>General Profile Parameters</h2>

                    <TextField
                        label="Base Domain"
                        fullWidth
                        size="small"
                        margin="normal"
                        defaultValue={configJSON.config["baseDomain"]}
                        onChange={(e) => { handleConfigChange(e.target.value, "baseDomain") }}
                    >
                    </TextField>
                    <TextField
                        label="Team Name"
                        fullWidth
                        variant="outlined"
                        size="small"
                        margin="normal"
                        defaultValue={configJSON.config["environmentPrefix"]}
                        onChange={(e) => { handleConfigChange(e.target.value, "environmentPrefix") }}
                    >
                    </TextField>

                    <TextField
                        label="Username"
                        fullWidth
                        variant="outlined"
                        size="small"
                        margin="normal"
                        defaultValue={configJSON.config["baseUser"]}
                        onChange={(e) => { handleConfigChange(e.target.value, "baseUser") }}
                    >
                    </TextField>

                    <TextField
                        fullWidth
                        type={showPassword ? 'text' : 'password'}
                        margin="normal"
                        size='small'
                        InputProps={{
                            endAdornment: (
                                <InputAdornment position="end">
                                    <IconButton
                                        aria-label="toggle password visibility"
                                        onClick={handleClickShowPassword}
                                        onMouseDown={handleMouseDownPassword}
                                    >
                                        {showPassword ? <Visibility /> : <VisibilityOff />}
                                    </IconButton>
                                </InputAdornment>
                            )
                        }}
                        label="Password"
                    />

                    <h2 className='text-xl font-semibold text-gray-400'>Additional Toggles</h2>
                    <div className='px-1 text-sm'>
                        <FormControlLabel
                            control={<Switch size="small"
                                defaultChecked={configJSON.config["standaloneMode"]}
                                onChange={(e) => { handleConfigChange(e.target.checked, "standaloneMode") }}
                            />}
                            label={<span style={{ fontSize: '16px' }}>Enable Standalone Mode</span>}
                        />
                        <FormControlLabel
                            control={<Switch size="small"
                                defaultChecked={configJSON.config["allowWorkloadsOnMaster"]}
                                onChange={(e) => { handleConfigChange(e.target.checked, "allowWorkloadsOnMaster") }} />}
                            label={<span style={{ fontSize: '16px' }}>Allow Workloads on Kubernetes Master</span>}
                        />
                        <FormControlLabel
                            control={<Switch size="small"
                                defaultChecked={configJSON.config["disableLinuxDesktop"]}
                                onChange={(e) => { handleConfigChange(e.target.checked, "disableLinuxDesktop") }}
                            />}
                            label={<span style={{ fontSize: '16px' }}>Disable Linux Desktop</span>}
                        />
                    </div>
                </div>
            </div>
        </div>)
};

const TabContent3 = ({ handleConfigChange }) => (
    <div className='text-left'>
        <div className='px-5 py-3'>
            <h2 className='text-3xl font-semibold'>Resource Configuration</h2>
            <p className='text-sm text-gray-400 text-justify'>Define how many physical resources you wish to allocate to the KX.AS.CODE virtual machines.</p>
        </div>
        <div className='px-5 py-3 bg-ghBlack grid grid-cols-12'>
            <div className='col-span-6'>
                <h2 className='text-xl font-semibold text-gray-400'>KX-Main Parameters</h2>
                {/* <p className='text-sm text-gray-400'>KX-Main nodes provide two core functions - Kubernetes master services as well as the desktop environment for easy access to deployed tools and documentation. Only the first KX-Main node hosts both the desktop environment, and the Kubernetes Master services. Subsequent KX-Main nodes host the Kubernetes Master services only.</p> */}
                <TextField
                    label="KX Main Nodes"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={1}
                    InputProps={{ inputProps: { min: 1, max: 10 } }}
                >
                </TextField>

                <TextField
                    label="KX Main Cores"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={8}
                    InputProps={{ inputProps: { min: 1, max: 30 } }}
                >
                </TextField>

                <TextField
                    label="KX Main RAM"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={19}
                    InputProps={{ inputProps: { min: 1, max: 50 } }}
                >
                </TextField>

                <h2 className='text-xl font-semibold text-gray-400'>KX-Worker Parameters</h2>
                <TextField
                    label="KX Node Nodes"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={0}
                    InputProps={{ inputProps: { min: 0, max: 10 } }}
                >
                </TextField>

                <TextField
                    label="KX Node Cores"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={6}
                    InputProps={{ inputProps: { min: 1, max: 30 } }}
                >
                </TextField>

                <TextField
                    label="KX Node RAM"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={8}
                    InputProps={{
                        startAdornment: <InputAdornment position="start">GB</InputAdornment>,
                        inputProps: { min: 0, max: 1000 }
                    }}
                >
                </TextField>

            </div>
        </div>
    </div>
);

const TabContent4 = ({ handleConfigChange }) => (
    <div className='text-left'>
        <div className='px-5 py-3'>
            <h2 className='text-3xl font-semibold'>Storage Parameters</h2>
            <p className='text-sm text-gray-400 text-justify'>Define the amount of storage allocated to KX.AS.CODE. There are two types - (1) fast local, but not portable storage, eg. tied to a host, and (2) slower, but portable network storage.</p>

        </div>
        <div className='px-5 py-3 bg-ghBlack grid grid-cols-12'>
            <div className='col-span-6'>
                <h2 className='text-xl font-semibold text-gray-400'>Network Storage</h2>
                {/* <p className='text-sm text-gray-400 text-justify'>Provision network storage with the set amount. The storage volume will be provisioned as a dedicated virtual drive in the virtual machine.</p> */}
                <TextField
                    InputProps={{
                        startAdornment: <InputAdornment position="start">GB</InputAdornment>,
                        inputProps: { min: 0, max: 1000 }
                    }}
                    label="Network Storage"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={60}
                >
                </TextField>

                <h2 className='text-xl font-semibold text-gray-400'>Local Storage Volumes</h2>
                {/* <p className='text-sm text-gray-400 text-justify'>Define the number of volumes of a given size will be "pre-provisioned" for consumption by Kubernetes workloads.</p> */}

                <TextField
                    InputProps={{
                        inputProps: { min: 0, max: 50 }
                    }}
                    label="1 GB"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={10}
                >
                </TextField>
                <TextField
                    InputProps={{
                        inputProps: { min: 0, max: 50 }
                    }}
                    label="1 GB"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={10}
                />
                <TextField
                    InputProps={{
                        inputProps: { min: 0, max: 50 }
                    }}
                    label="5 GB"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={10}
                />
                <TextField
                    InputProps={{
                        inputProps: { min: 0, max: 50 }
                    }}
                    label="10 GB"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={0}
                />
                <TextField
                    InputProps={{
                        inputProps: { min: 0, max: 50 }
                    }}
                    label="30 GB"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={0}
                />
                <TextField
                    InputProps={{
                        inputProps: { min: 0, max: 50 }
                    }}
                    label="50 GB"
                    type='number'
                    fullWidth
                    size="small"
                    margin="normal"
                    defaultValue={0}
                />

            </div>
        </div>
    </div>
);

const TabContent5 = ({ handleConfigChange }) => (
    <div className='text-left'>
        <div className='px-5 py-3'>
            <h2 className='text-3xl font-semibold'>User Provisioning</h2>
            <p className='text-sm text-gray-400 text-justify'>Define additional users to provision in the KX.AS.CODE environment. This is optional. If you do not specify additional users, then only the base user will be available for logging into the desktop and all provisioned tools.</p>
        </div>
        <div className='px-5 py-3 bg-ghBlack gap-2'>
            <div className='flex gap-2'>
                <TextField
                    required
                    InputProps={{
                    }}
                    label="First Name"
                    type='text'
                    fullWidth
                    size="small"
                    margin="normal"
                />
                <TextField
                    InputProps={{
                    }}
                    label="Surname"
                    type='text'
                    fullWidth
                    size="small"
                    margin="normal"
                />
                <TextField
                    InputProps={{
                    }}
                    label="E-Mail"
                    type='email'
                    fullWidth
                    size="small"
                    margin="normal"
                />
            </div>

            <div className='flex gap-2'>
                <TextField
                    label="Role"
                    select
                    fullWidth
                    variant="outlined"
                    size="small"
                    margin="normal"
                    defaultValue="admin"
                >
                    <MenuItem value="admin">Admin</MenuItem>
                    <MenuItem value="normal">Normal</MenuItem>

                </TextField>

                <TextField
                    label="Keyboard Layout"
                    select
                    fullWidth
                    variant="outlined"
                    size="small"
                    margin="normal"
                    defaultValue="german"
                >
                    <MenuItem value="german">German</MenuItem>
                    <MenuItem value="en-us">English (US)</MenuItem>
                    <MenuItem value="en-gb">English (GB)</MenuItem>
                    <MenuItem value="french">French</MenuItem>
                    <MenuItem value="spanish">Spanish</MenuItem>

                </TextField>
                <button type="submit items-center"
                    className='border border-white mt-4 h-10 px-3'>
                    <PersonAddAltIcon />
                </button>

            </div>

        </div>
        <UserTable />
    </div>
);

const TabContent6 = ({ handleConfigChange }) => (
    <div className='text-left'>
        <div className='px-5 py-3'>
            <h2 className='text-3xl font-semibold'>Custom Global Variables</h2>
            <p className='text-sm text-gray-400 text-justify'>Set key/value pairs that can be used by solutions when they are being installed.</p>
        </div>
        <div className='px-5 py-3 bg-ghBlack gap-2 flex items-center'>

            <TextField
                required
                InputProps={{
                }}
                label="Key"
                type='text'
                fullWidth
                size="small"
                margin="normal"
            />

            <TextField
                required
                InputProps={{
                }}
                label="Value"
                type='text'
                fullWidth
                size="small"
                margin="normal"
            />

            <button className='border border-white mt-2 h-10 px-3'>
                {/* <AddCircleOutlineIcon fontSize='medium' /> */}
                <AddIcon />
            </button>

        </div>
        <div className='flex'>
            <GlobalVariablesTable />
        </div>
    </div>
)

export default TabMenu;
