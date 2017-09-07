/*
* Copyright (c) 2017 Robert San <robertsanseries@gmail.com>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

using Ciano.Config;
using Ciano.Views;
using Ciano.Widgets;
using Ciano.Objects;
using Ciano.Utils;
using Ciano.Enums;

namespace Ciano.Controllers {

    /**
     * The {@code ConverterController} class is responsible for handling all the major
     * rules and actions of the application.
     *
     * @since 0.1.0
     */
    public class ConverterController {

        public  Gee.ArrayList<RowConversion>    convertions;
        private Gee.ArrayList<ItemConversion>   list_items;
        private Gtk.Application                 application;
        private Ciano.Config.Settings           settings;
        private ConverterView                   converter_view;
        private DialogPreferences               dialog_preferences;
        private DialogConvertFile               dialog_convert_file;       
        private TypeItemEnum                    type_item;
        private string                          name_format_selected;
        private int                             id_item;

        /**
         * Constructs a new object {@code ConverterView} responsible for:
         * 1 - Initialize values that are handled by the class.
         * 2 - Get an instance of the {@code Settings} class.
         * 3 - Start the Items array for conversion and the item counter.
         * 4 - Load the methods that are responsible for the action of the dialogs. 
         *
         * @see Ciano.Views.ConverterView
         * @see Ciano.Config.Settings
         * @see Ciano.Objects.ItemConversion
         * @see on_activate_button_preferences
         * @see on_activate_button_item
         * @param {@code Gtk.ApplicationWindow} window
         * @param {@code Gtk.Application}       application
         * @param {@code ConverterView}         converter_view
         */
        public ConverterController (Gtk.ApplicationWindow window, Gtk.Application application,  ConverterView converter_view) {
            this.converter_view = converter_view;
            this.application    = application;
            
            this.settings   = Ciano.Config.Settings.get_instance ();
            this.list_items = new Gee.ArrayList<ItemConversion> ();
            this.id_item    = 1;
            
            on_activate_button_preferences (window);
            on_activate_button_item (window);
        }

        /**
         * When select the preferences option in the settings icon located in the headerbar, 
         * this method will call the "DialogPreferences".
         *
         * @see Ciano.Widgets.DialogPreferences
         * @param  {@code Gtk.ApplicationWindow} window
         * @return {@code void}
         */
        private void on_activate_button_preferences (Gtk.ApplicationWindow window) {
            this.converter_view.headerbar.item_selected.connect (() => {
                this.dialog_preferences = new DialogPreferences (window);
                this.dialog_preferences.show_all ();
            }); 
        }

        /**
         * When selecting which type to convert:
         * 1 - Stores the name of the selected type.
         * 2 - Call the {@code mount_array_with_supported_formats} method to define the types of formats that will be
         *     possible to add in the {@code Gtk.TreeView} of {@code DialogConvertFile} for conversion.
         * 3 - Build the {@code DialogConvertFile}.
         *
         * @see Ciano.Widgets.DialogConvertFile
         * @see mount_array_with_supported_formats
         * @param  {@code Gtk.ApplicationWindow} window
         * @return {@code void}
         */
        private void on_activate_button_item (Gtk.ApplicationWindow window) {
            this.converter_view.source_list.item_selected.connect ((item) => {

                this.name_format_selected = item.name;
                var types = mount_array_with_supported_formats (item.name);

                this.dialog_convert_file = new DialogConvertFile (this, types, item.name, window);
                this.dialog_convert_file.show_all ();
            });
        }

        /**
         * Method responsible for adding one or more files to {@code Gtk.TreeView} from {@code DialogConvertFile}.
         *
         * @see Ciano.Widgets.DialogConvertFile
         * @param  {@code Gtk.Dialog}    parent_dialog
         * @param  {@code Gtk.TreeView}  tree_view
         * @param  {@code Gtk.TreeIter}  iter
         * @param  {@code Gtk.ListStore} list_store
         * @param  {@code string []}     formats
         * @return {@code void}
         */
        public void on_activate_button_add_file (Gtk.Dialog parent_dialog, Gtk.TreeView tree_view, Gtk.TreeIter iter, Gtk.ListStore list_store, string [] formats) {
            var chooser_file = new Gtk.FileChooserDialog (Properties.TEXT_SELECT_FILE, parent_dialog, Gtk.FileChooserAction.OPEN);
            chooser_file.select_multiple = true;

            var filter = new Gtk.FileFilter ();

            foreach (string format in formats) {
                filter.add_pattern ("*.".concat (format.down ()));
            }       

            chooser_file.set_filter (filter);
            chooser_file.add_buttons ("Cancel", Gtk.ResponseType.CANCEL, "Add", Gtk.ResponseType.OK);

            if (chooser_file.run () == Gtk.ResponseType.OK) {

                SList<string> uris = chooser_file.get_filenames ();

                foreach (unowned string uri in uris)  {
                    
                    var file         = File.new_for_uri (uri);
                    int index        = file.get_basename ().last_index_of("/");
                    string name      = file.get_basename ().substring(index + 1, -1);
                    string directory = file.get_basename ().substring(0, index + 1);

                    if (name.length > 50) {    
                        name = name.slice(0, 48) + "...";
                    }

                    if (directory.length > 50) {    
                        directory = directory.slice(0, 48) + "...";
                    }

                    list_store.append (out iter);
                    list_store.set (iter, 0, name, 1, directory);
                    tree_view.expand_all ();
                }
            }

            chooser_file.hide ();
        }
        
        /**
         * Removeable add-on method added in {@code Gtk.TreeView} {@code DialogConvertFile}
         * 
         * @param  {@code Gtk.Dialog}     parent_dialog
         * @param  {@code Gtk.TreeView}   tree_view
         * @param  {@code Gtk.ListStore}  list_store
         * @param  {@code Gtk.ToolButton} button_remove
         * @return {@code void}
         */
        public void on_activate_button_remove (Gtk.Dialog parent_dialog, Gtk.TreeView tree_view, Gtk.ListStore list_store, Gtk.ToolButton button_remove) {

            Gtk.TreePath path;
            Gtk.TreeViewColumn column;

            tree_view.get_cursor (out path, out column);

            if(path != null) {
                Gtk.TreeIter iter;
                
                list_store.get_iter (out iter, path);
                list_store.remove (iter);

                if (path.to_string () == "0") {
                    button_remove.sensitive = false;
                }
            }
        }
        
        /**
         * Method responsible for initiating conversion of items added to {@code Gtk.TreeView} from {@code DialogConvertFile}.
         * In each foreach item {@code load_list_for_conversion} will perform the following action:
         * 1 - Get the name and directory of the file.
         * 2 - Creates an {@code ItemConversion} to store the status of each item.
         * 3 - Adds {@code ItemConversion} to {@code list list_items}.
         * 4 - Executes the {@code execute_command_async} method responsible for executing the conversion of the item to a subprocess.
         * 
         * @see Ciano.Configs.Constants
         * @see Ciano.Objects.ItemConvertion
         * @param  {@code Gtk.ListStore} list_store
         * @param  {@code string}        name_format
         * @return {@code void}
         */
        public void on_activate_button_start_conversion (Gtk.ListStore list_store, string name_format){

            this.converter_view.list_conversion.stack.set_visible_child_name (Constants.LIST_BOX_VIEW);
            this.converter_view.list_conversion.stack.show_all ();

            Gtk.TreeModelForeachFunc load_list_for_conversion = (model, path, iter) => {
                GLib.Value cell1;
                GLib.Value cell2;

                list_store.get_value (iter, 0, out cell1);
                list_store.get_value (iter, 1, out cell2);

                var item = new ItemConversion (
                    id_item, 
                    cell1.get_string (), 
                    cell2.get_string (),
                    this.name_format_selected,
                    0,
                    this.type_item
                );

                this.list_items.add (item);
                
                string uri = item.directory + item.name;
                execute_command_async.begin (get_command (uri), item, name_format);
                
                this.id_item++;
               
                return false;
            };

            list_store.foreach (load_list_for_conversion);
        }
        
        /**
         * Method to execute the command assembled by the {@code get_command} method and create a subprocess to get the
         * command output response. Doing the manipulation with each returned return (every new string returned).
         * 1 - Execute the command.
         * 2 - Create the subprocess
         * 3 - Force the return for each new line using {@code yield}.
         * 4 - Checks if you hear any errors during the conversion.
         * 5 - Validates the notation rule defined in DialogPreferences.
         *
         * @see Ciano.Enums.TypeItemEnum
         * @param  {@code string[]}       spawn_args
         * @param  {@code ItemConversion} item
         * @param  {@code string}         name_format
         * @return {@code void}
         */
        public async void execute_command_async (string[] spawn_args, ItemConversion item, string name_format) {
            try {
                var launcher            = new SubprocessLauncher (SubprocessFlags.STDERR_PIPE);
                var subprocess          = launcher.spawnv (spawn_args);
                var input_stream        = subprocess.get_stderr_pipe ();
                var data_input_stream   = new DataInputStream (input_stream);

                var icon = get_type_icon (item);
                var row  = create_row_conversion (icon, item.name, name_format, subprocess);
                
                this.converter_view.list_conversion.list_box.add (row);
                
                int total = 0;

                    while (true) {
                        string str_return = yield data_input_stream.read_line_utf8_async ();
                        
                        if (str_return == null) {
                            WidgetUtil.set_visible (row.button_cancel, false);
                            WidgetUtil.set_visible (row.button_remove, true);
                            
                            if(item.type_item == TypeItemEnum.IMAGE) {
                               row.progress_bar.set_fraction (1);
                            }

                            send_notification (item.name, Properties.TEXT_SUCESS_IN_CONVERSION);
                            break; 
                        } else {
                            message(str_return.replace("\\u000d", "\n"));
                            process_line (str_return, ref row.progress_bar,ref row.size_time_bitrate, ref total);
                        }
                    }
            } catch (SpawnError e) {
                GLib.critical ("Error: %s\n", e.message);
            } catch (Error e) {
                GLib.message("Erro %s\n", e.message);
            }
        }

        /**
         * Create row conversion.
         *
         * @see Ciano.Widgets.RowConversion 
         * @see Ciano.Utils.WidgetUtil
         * @param  {@code string}     icon
         * @param  {@code string}     item_name
         * @param  {@code string}     name_format
         * @param  {@code Subprocess} subprocess
         * @return {@code void}
         */
        private RowConversion create_row_conversion (string icon, string item_name, string name_format, Subprocess subprocess) {
            var row = new RowConversion (icon, item_name, 0, name_format);
            row.button_cancel.clicked.connect(() => {
                subprocess.force_exit ();
                WidgetUtil.set_visible (row.button_cancel, false);
                WidgetUtil.set_visible (row.button_remove, true);
            });
                
            WidgetUtil.set_visible (row.button_remove, false);                

            return row;
        }

        /**
         * Responsible for returning the icon name to the type defined in {@code ItemConversion}.
         *
         * @see Ciano.Objects.ItemConversion
         * @see Ciano.Enums.TypeItemEnum
         * @see Ciano.Utils.StringUtil
         * @param  {@code ItemConversion} item
         * @return {@code string}         icon
         */
        private string get_type_icon (ItemConversion item) {
            string icon = StringUtil.EMPTY;

            switch (item.type_item) {
                case TypeItemEnum.VIDEO:
                    icon = "media-video";
                    break;
                case TypeItemEnum.MUSIC:
                    icon = "audio-x-generic";
                    break;
                case TypeItemEnum.IMAGE:
                    icon = "image";
                    break;
                default:
                    icon = "file";
                    break;
            }

            return icon;
        }
        
        /**
         * Responsible for processing the returned row and validate the return and execution of actions accordingly.
         * 1 - Monitors the time, size, duration, and bitrate of each item.
         * 2 - Also check the error if it happens.
         *
         * @see Ciano.Configs.Properties
         * @see Ciano.Utils.StringUtil
         * @see Ciano.Utils.TimeUtil
         * @param      {@code string}           str_return
         * @param  ref {@code Gtk.ProgressBar}  progress_bar
         * @param  ref {@code Gtk.Label}        size_time_bitrate
         * @param  ref {@code int}              total
         * @return {@code void}
         */
        private void process_line (string str_return,  ref Gtk.ProgressBar progress_bar, ref Gtk.Label size_time_bitrate, ref int total) {
            string time     = StringUtil.EMPTY;
            string size     = StringUtil.EMPTY;
            string bitrate  = StringUtil.EMPTY;

            if (str_return.contains ("Duration:")) {
                int index       = str_return.index_of ("Duration:");
                string duration = str_return.substring (index + 10, 11);

                total = TimeUtil.duration_in_seconds (duration);
            }

            if (str_return.contains ("time=") && str_return.contains ("size=") && str_return.contains ("bitrate=") ) {
                int index_time  = str_return.index_of ("time=");
                time            = str_return.substring ( index_time + 5, 11);

                int loading     = TimeUtil.duration_in_seconds (time);
                double progress = 100 * loading / total;
                progress_bar.set_fraction (progress);
        
                int index_size  = str_return.index_of ("size=");
                size            = str_return.substring ( index_size + 5, 11);
            
                int index_bitrate = str_return.index_of ("bitrate=");
                bitrate           = str_return.substring ( index_bitrate + 8, 11);

                size_time_bitrate.label = Properties.TEXT_SIZE_CUSTOM + size.strip () + Properties.TEXT_TIME_CUSTOM + time.strip () + Properties.TEXT_BITRATE_CUSTOM + bitrate.strip ();
            }
        }

        /**
         * Assemble the command to be executed by the terminal depending on the type of the item.
         *
         * @see Ciano.Enums.TypeItemEnum
         * @see get_uri_new_file
         * @param  {@code string} uri
         * @return {@code void}
         */
        public string[] get_command (string uri) {
            var array = new GenericArray<string> ();
            var new_file = get_uri_new_file (uri);
            
            if (this.type_item == TypeItemEnum.VIDEO || this.type_item == TypeItemEnum.MUSIC) {
                array.add ("ffmpeg");
                array.add ("-y");
                array.add ("-i");
                array.add (uri);
                array.add (new_file);
            } else if (this.type_item == TypeItemEnum.IMAGE) {
                array.add ("convert");
                array.add (uri);
                array.add (new_file);
            }

            return array.data;
        }

        /**
         * Return the uri with the filename and extension to which it will be converted.
         * Method obeys the "paste output" rules in {@code DialogPreferences}.
         * 
         * @param  {@code string uri}
         * @return {@code void}
         */
        private string get_uri_new_file (string uri) {
            string new_file;

            if (this.settings.output_source_file_folder) {
                int index = uri.last_index_of(".");
                new_file = uri.substring(0, index + 1) + this.name_format_selected.down ();
            } else {
                int index_start = uri.last_index_of("/");
                int index_end = uri.last_index_of(".");
                var file = uri.substring(index_start, index_start - index_end);

                int index = file.last_index_of(".");
                new_file = this.settings.output_folder + file.substring(0, index + 1) + this.name_format_selected.down ();
            }

            return new_file;
        }

        /**
         * Send notification.
         * 
         * @param  {@code string}    file_name
         * @param  {@code string}    body_text
         * @return {@code void}
         */
        private void send_notification (string file_name, string body_text) {
            var notification = new Notification (file_name);
            var image = new Gtk.Image.from_icon_name ("com.github.robertsanseries.ciano", Gtk.IconSize.DIALOG);
            notification.set_body (body_text);
            notification.set_icon (image.gicon);
            this.application.send_notification ("finished", notification);
        }

        /**
         * Mount array with supported formats.
         *
         * @see Ciano.Configs.Constants
         * @see get_array_formats_videos
         * @param  {@code string} name_format
         * @return {@code void}
         */
        private string [] mount_array_with_supported_formats (string name_format) {
            string [] formats = null;
            
            switch (name_format) {
                case Constants.TEXT_MP4:
                    formats = get_array_formats_videos (Constants.TEXT_MP4);
                    break;
                case Constants.TEXT_3GP:
                    formats = get_array_formats_videos (Constants.TEXT_3GP);
                    break;
                case Constants.TEXT_MPG:
                    formats = get_array_formats_videos (Constants.TEXT_MPG);
                    break;
                case Constants.TEXT_AVI:
                    formats = get_array_formats_videos (Constants.TEXT_AVI);
                    break;
                case Constants.TEXT_WMV:
                    formats = get_array_formats_videos (Constants.TEXT_WMV);
                    break;
                case Constants.TEXT_FLV:
                    formats = get_array_formats_videos (Constants.TEXT_FLV);
                    break;
                case Constants.TEXT_SWF:
                    formats = get_array_formats_videos (Constants.TEXT_SWF);
                    break;

                case Constants.TEXT_MP3:
                    formats = get_array_formats_music (Constants.TEXT_MP3);
                    break;
                case Constants.TEXT_WMA:
                    formats = get_array_formats_music (Constants.TEXT_WMA);
                    break;
                case Constants.TEXT_OGG:
                    formats = get_array_formats_music (Constants.TEXT_OGG);
                    break;
                case Constants.TEXT_AAC:
                    formats = get_array_formats_music (Constants.TEXT_AAC);
                    break;
                case Constants.TEXT_WAV:
                    formats = get_array_formats_music (Constants.TEXT_WAV);
                    break;

                case Constants.TEXT_JPG:
                    formats = get_array_formats_image (Constants.TEXT_JPG);
                    break;
                case Constants.TEXT_BMP:
                    formats = get_array_formats_image (Constants.TEXT_BMP);
                    break;
                case Constants.TEXT_PNG:
                    formats = get_array_formats_image (Constants.TEXT_PNG);
                    break;
                case Constants.TEXT_TIF:
                    formats = get_array_formats_image (Constants.TEXT_TIF);
                    break;
                case Constants.TEXT_ICO:
                    formats = get_array_formats_image (Constants.TEXT_ICO);
                    break;
                case Constants.TEXT_GIF:
                    formats = get_array_formats_image (Constants.TEXT_GIF);
                    break;
                case Constants.TEXT_TGA:
                    formats = get_array_formats_image (Constants.TEXT_TGA);
                    break;
            }

            return formats;
        }

        /**
         * Get array formats videos.
         *
         * @see Ciano.Configs.Constants
         * @see Ciano.Enums.TypeItemEnum
         * @param  {@code string} format_video
         * @return {@code string []}
         */
        private string [] get_array_formats_videos (string format_video) {
            var array = new GenericArray<string> ();

            this.type_item = TypeItemEnum.VIDEO;

            if(format_video != Constants.TEXT_MP4) {
                array.add (Constants.TEXT_MP4);    
            }
            
            if(format_video != Constants.TEXT_3GP) {
                array.add (Constants.TEXT_3GP);    
            }

            if(format_video != Constants.TEXT_MPG) {
                array.add (Constants.TEXT_MPG);    
            }

            if(format_video != Constants.TEXT_AVI) {
                array.add (Constants.TEXT_AVI);    
            }

            if(format_video != Constants.TEXT_WMV) {
                array.add (Constants.TEXT_WMV);    
            }

            if(format_video != Constants.TEXT_FLV) {
                array.add (Constants.TEXT_FLV);    
            }

            if(format_video != Constants.TEXT_SWF) {
                array.add (Constants.TEXT_SWF);    
            }

            return array.data;
        }

        /**
         * Get array formats music.
         *
         * @see Ciano.Configs.Constants
         * @see Ciano.Enums.TypeItemEnum
         * @param  {@code string} format_music
         * @return {@code void}
         */
        private string [] get_array_formats_music (string format_music) {
            var array = new GenericArray<string> ();

            this.type_item = TypeItemEnum.MUSIC;

            if(format_music != Constants.TEXT_MP3) {
                array.add (Constants.TEXT_MP3);    
            }
            
            if(format_music != Constants.TEXT_WMA) {
                array.add (Constants.TEXT_WMA);    
            }

            if(format_music != Constants.TEXT_AMR) {
                array.add (Constants.TEXT_AMR);    
            }

            if(format_music != Constants.TEXT_OGG) {
                array.add (Constants.TEXT_OGG);    
            }

            if(format_music != Constants.TEXT_AAC) {
                array.add (Constants.TEXT_AAC);    
            }

            if(format_music != Constants.TEXT_WAV) {
                array.add (Constants.TEXT_WAV);    
            }

            return array.data;
        }

        /**
         * Get array formats image.
         *
         * @see Ciano.Configs.Constants
         * @see Ciano.Enums.TypeItemEnum
         * @param  {@code string} format_image
         * @return {@code string []}
         */
        private string [] get_array_formats_image (string format_image) {
            var array = new GenericArray<string> ();

            this.type_item = TypeItemEnum.IMAGE;

            if(format_image != Constants.TEXT_JPG) {
                array.add (Constants.TEXT_JPG);    
            }
            
            if(format_image != Constants.TEXT_BMP) {
                array.add (Constants.TEXT_BMP);    
            }

            if(format_image != Constants.TEXT_PNG) {
                array.add (Constants.TEXT_PNG);    
            }

            if(format_image != Constants.TEXT_TIF) {
                array.add (Constants.TEXT_TIF);    
            }

            if(format_image != Constants.TEXT_ICO) {
                array.add (Constants.TEXT_ICO);    
            }

            if(format_image != Constants.TEXT_GIF) {
                array.add (Constants.TEXT_GIF);    
            }

            if(format_image != Constants.TEXT_TGA) {
                array.add (Constants.TEXT_TGA);    
            }

            return array.data;
        }
    }
}