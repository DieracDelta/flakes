// Custom Digitransit configuration for NY/CT/East Coast region
import configMerger from '../util/configMerger'
import defaultConfig from './config.default'

const CONFIG = 'newyork'
const APP_TITLE = 'Transit Planner'
const APP_DESCRIPTION = 'Trip planner for New York and Connecticut'

const API_URL = process.env.API_URL || ''
const OTP_URL = process.env.OTP_URL || `${API_URL}/otp/`

export default configMerger(defaultConfig, {
	CONFIG,

	// Disable API subscription parameters (not needed for self-hosted services)
	hasAPISubscriptionQueryParameter: false,

	// URL configuration
	URL: {
		OTP: OTP_URL,
		// Disable vector tile overlays (we don't have a vector tile server)
		// Use empty object with default key instead of null to avoid "Cannot read properties of null" errors
		STOP_MAP: { default: '' },
		REALTIME_STOP_MAP: { default: '' },
		RENTAL_STATION_MAP: { default: '' },
		REALTIME_RENTAL_STATION_MAP: { default: '' },
		REALTIME_RENTAL_VEHICLE_MAP: { default: '' },
		PARK_AND_RIDE_MAP: { default: '' },
		PARK_AND_RIDE_GROUP_MAP: { default: '' },
	},

	// Language settings - English default
	defaultLanguage: 'en',
	availableLanguages: ['en', 'es'],

	// Branding
	title: APP_TITLE,
	appBarLink: { name: APP_TITLE, href: '/' },

	// No favicon/logo customization for now - use defaults

	// Default map center (New York City)
	defaultEndpoint: {
		address: 'New York City',
		lat: 40.7128,
		lon: -74.006,
	},

	// Map bounds covering NY, CT, NJ, and surrounding area
	map: {
		areaBounds: {
			corner1: [42.5, -71.0], // Northeast (Boston area)
			corner2: [39.5, -75.5], // Southwest (Philadelphia area)
		},
		minZoom: 7,
		maxZoom: 18,
	},

	defaultMapZoom: 10,

	// Search bounds for geocoding
	searchParams: {
		'boundary.rect.min_lat': 39.5,
		'boundary.rect.max_lat': 42.5,
		'boundary.rect.min_lon': -75.5,
		'boundary.rect.max_lon': -71.0,
	},

	// Search polygon for autocomplete (covers NY, CT, NJ, parts of PA, MA)
	useSearchPolygon: true,
	areaPolygon: [
		[-75.5, 39.5], // SW - Philadelphia area
		[-71.0, 39.5], // SE - Atlantic
		[-71.0, 42.5], // NE - Boston area
		[-75.5, 42.5], // NW - Albany area
		[-75.5, 39.5], // Close polygon
	],

	// Let OTP provide feed IDs automatically
	feedIds: [],

	// Disable Helsinki-specific features
	showTicketInformation: false,
	showRouteInformation: false,
	cityBike: {
		showCityBikes: false,
	},

	// Use imperial units for US
	imperialEnabled: true,

	// Timezone for NY
	timezoneData: 'America/New_York|EST EDT|50 40|0101|1Lz50 1zb0 Op0',

	// Social media / metadata
	socialMedia: {
		title: APP_TITLE,
		description: APP_DESCRIPTION,
	},

	// Menu content
	menu: {
		copyright: { label: `Transit Planner ${new Date().getFullYear()}` },
		content: [
			{
				name: 'about-this-service',
				route: '/about',
			},
		],
	},

	// About page content
	aboutThisService: {
		en: [
			{
				header: 'About this service',
				paragraphs: [
					'This service provides trip planning for public transit in the New York and Connecticut region.',
					'Service is built on the Digitransit platform with OpenTripPlanner routing.',
				],
			},
		],
		es: [
			{
				header: 'Acerca de este servicio',
				paragraphs: [
					'Este servicio proporciona planificacion de viajes para el transporte publico en la region de Nueva York y Connecticut.',
					'El servicio esta construido en la plataforma Digitransit con enrutamiento OpenTripPlanner.',
				],
			},
		],
	},

	// Colors - neutral theme
	colors: {
		primary: '#007ac9',
		iconColors: {
			'mode-bus': '#007ac9',
			'mode-rail': '#8c4799',
			'mode-subway': '#ff6319',
			'mode-tram': '#00985f',
			'mode-ferry': '#00b9e4',
		},
	},
})
